#!/usr/bin/env python3
"""Optional, bounded GoFish comparison. Public fixtures and loopback only."""
import json
import os
import ssl
import subprocess
import tempfile
import threading
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from test_reference import COMMIT, FILES, HARDWARE_FILES, load_routes
from hardware_fixtures import assert_hardware, hardware_expected, modern_routes

REPO = Path(__file__).resolve().parents[1]
ROOT = "/redfish/v1"
SESSION = ROOT + "/SessionService/Sessions"
TOKEN = "synthetic-comparison-token"
PRIVATE = "synthetic-private-response"
KINDS = ("systems", "chassis", "managers")
ENV = {**os.environ, "RUST_LOG": "error"}


def project(resource):
    return dict(zip(("uri", "id", "name", "type", "power"),
                    (resource.get(k) for k in ("@odata.id", "Id", "Name", "@odata.type", "PowerState"))))


def canonical(result):
    for kind in KINDS:
        if kind in result:
            result[kind] = sorted(result[kind], key=lambda item: item["uri"])
    return result


@contextmanager
def fixture(routes, protocol=False, tls=None):
    state = {"login": 0, "logout": 0, "wrong": 0, "active": False, "visited": set(), "unexpected": [], "requests": []}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def respond(self, status, data, **headers):
            body = data if isinstance(data, bytes) else json.dumps(data).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            for key, value in headers.items():
                self.send_header(key.replace("_", "-"), value)
            self.end_headers()
            self.wfile.write(body)

        def unexpected(self):
            state["unexpected"].append((self.command, self.path))
            self.respond(405, {})

        def do_GET(self):
            state["requests"].append([self.command, self.path])
            state["visited"].add(self.path)
            if protocol and self.path != ROOT + "/" and (
                not state["active"] or self.headers.get("X-Auth-Token") != TOKEN
            ):
                return self.respond(401, {})
            if self.path in routes:
                data = routes[self.path]
                if isinstance(data, tuple):
                    return self.respond(*data)
                return self.respond(200, data)
            if protocol and self.path == ROOT + "/Forbidden":
                return self.respond(403, {"error": {
                    "code": "Base.1.0.GeneralError", "message": PRIVATE,
                    "@Message.ExtendedInfo": [{"MessageId": "Base.1.0.InsufficientPrivilege", "MessageArgs": ["synthetic-password"]}],
                }})
            if protocol and self.path == ROOT + "/Missing":
                return self.respond(404, {})
            if protocol and self.path == ROOT + "/Invalid":
                return self.respond(200, b"not JSON")
            if protocol and self.path == ROOT + "/Cycle":
                return self.respond(200, {"Members": [], "Members@odata.nextLink": self.path})
            self.unexpected()

        def do_POST(self):
            if not protocol or self.path != SESSION:
                return self.unexpected()
            # MoonBit streams JSON; GoFish supplies Content-Length.
            if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
                body = b""
                while True:
                    size = int(self.rfile.readline().strip(), 16)
                    if size == 0:
                        self.rfile.readline()
                        break
                    assert len(body) + size <= 4096
                    body += self.rfile.read(size)
                    self.rfile.read(2)
            else:
                size = int(self.headers.get("Content-Length", "0"))
                assert size <= 4096
                body = self.rfile.read(size)
            credentials = json.loads(body)
            if credentials == {"UserName": "synthetic-user", "Password": "synthetic-wrong"}:
                state["wrong"] += 1
                return self.respond(401, {})
            if credentials != {"UserName": "synthetic-user", "Password": "synthetic-password"} or state["active"]:
                return self.unexpected()
            state["login"] += 1
            state["active"] = True
            self.respond(201, {"@odata.id": SESSION + "/1", "Id": "1", "Name": "Synthetic session", "Password": None},
                         X_Auth_Token=TOKEN, Location=SESSION + "/1")

        def do_DELETE(self):
            if not protocol or self.path != SESSION + "/1" or not state["active"] or self.headers.get("X-Auth-Token") != TOKEN:
                return self.unexpected()
            state["logout"] += 1
            state["active"] = False
            self.respond(204, b"")

        do_PATCH = do_PUT = unexpected

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    if tls:
        server.socket = tls.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"{'https' if tls else 'http'}://127.0.0.1:{server.server_port}", state
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


def run_adapter(name, command, mode, endpoint, ca="-"):
    result = subprocess.run(command + [mode, endpoint, str(ca)], cwd=REPO, env=ENV,
                            capture_output=True, text=True, timeout=120)
    # Do not reproduce unfiltered GoFish errors, tokens or free-form server text.
    for text in ("synthetic-password", TOKEN, PRIVATE):
        assert text not in result.stdout + result.stderr, f"{name}: output minimization failed"
    assert result.returncode == 0, f"{name}: {mode} adapter failed (exit {result.returncode})"
    return canonical(json.loads(result.stdout))


def main():
    expanded = load_routes(expanded=True)
    # Reuse already verified bytes without refetching the baseline.
    routes = {uri: data for uri, data in expanded.items() if uri == ROOT + "/" or uri.removeprefix(ROOT + "/") + "/index.json" in FILES}
    modern = modern_routes()
    expected = {"root": project(json.loads(routes[ROOT + "/"]))}
    for kind in KINDS:
        collection = json.loads(routes[ROOT + "/" + kind.capitalize()])
        expected[kind] = [project(json.loads(routes[item["@odata.id"]])) for item in collection["Members"]]
    expected = canonical(expected)
    synthetic = {
        ROOT + "/": {"Id": "RootService", "Links": {"Sessions": {"@odata.id": SESSION}},
                      **{kind: {"@odata.id": ROOT + "/" + kind} for kind in ("Systems", "Chassis")}},
        ROOT + "/Systems": {"Members": [{"@odata.id": ROOT + "/Systems/1"}], "Members@odata.nextLink": ROOT + "/Systems?$skip=1"},
        ROOT + "/Systems?$skip=1": {"Members": [{"@odata.id": ROOT + "/Systems/2"}]},
        ROOT + "/Chassis": {"Members": []},
    }
    for ident in ("1", "2"):
        uri = ROOT + "/Systems/" + ident
        synthetic[uri] = {"@odata.id": uri, "@odata.type": "#ComputerSystem.v1_0_0.ComputerSystem",
                          "Id": ident, "Name": "Synthetic system " + ident, "PowerState": "On"}
    protocol_expected = {
        "wrong_password": 401, "systems": [project(synthetic[ROOT + "/Systems/" + i]) for i in ("1", "2")],
        "empty_chassis": 0, "forbidden": {"status": 403, "code": "Base.1.0.GeneralError", "message_ids": ["Base.1.0.InsufficientPrivilege"]},
        "missing": 404, "invalid_json": True, "pagination_cycle": True,
    }
    with tempfile.TemporaryDirectory(prefix="moonredfish-comparison-") as tmp:
        tmp = Path(tmp)
        binary = tmp / "gofish-compare"
        subprocess.run(["go", "build", "-mod=readonly", "-o", str(binary), "."],
                       cwd=REPO / "tools/gofish", env=ENV, check=True, timeout=180)
        commands = {
            "moonredfish": ["moon", "run", "examples/compare", "--target", "native", "--"],
            "GoFish v0.27.0": [str(binary)],
        }
        cert, key, config = (tmp / name for name in ("cert.pem", "key.pem", "openssl.cnf"))
        config.write_text("[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n[dn]\nCN=synthetic.example.invalid\n[ext]\nsubjectAltName=IP:127.0.0.1\nbasicConstraints=critical,CA:TRUE\n")
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-config", str(config),
                        "-keyout", str(key), "-out", str(cert)], check=True, capture_output=True)
        tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls.load_cert_chain(cert, key)
        for name, command in commands.items():
            with fixture(routes) as (endpoint, state):
                assert run_adapter(name, command, "inventory", endpoint) == expected, f"{name}: public field mismatch"
                assert state["visited"] == set(routes) and not state["unexpected"]
            for hardware_routes in (expanded, modern):
                with fixture(hardware_routes) as (endpoint, state):
                    assert_hardware(run_adapter(name, command, "hardware", endpoint), hardware_expected(hardware_routes), name)
                    assert state["visited"] == set(hardware_routes) and not state["unexpected"]
            with fixture(synthetic, protocol=True, tls=tls) as (endpoint, state):
                assert run_adapter(name, command, "protocol", endpoint, cert) == protocol_expected, f"{name}: protocol mismatch"
                assert state["login"] == state["logout"] == state["wrong"] == 1 and not state["active"]
                assert state["visited"] == set(synthetic) | {ROOT + "/" + p for p in ("Forbidden", "Missing", "Invalid", "Cycle")}
                assert not state["unexpected"]
            with fixture(synthetic, protocol=True, tls=tls) as (endpoint, state):
                assert run_adapter(name, command, "reject_tls", endpoint) == {"tls_rejected": True}
                assert not state["visited"] and state["login"] == 0
            print(f"{name}: pinned inventory and hardware fields, synthetic modern hardware, pagination, 201 session cleanup, HTTP errors, JSON and TLS passed")
        print(f"comparison source: DMTF mockups@{COMMIT}; {len(FILES) + len(HARDWARE_FILES)} hashes verified; defined non-null hardware fields only; no physical BMC or performance claim")


if __name__ == "__main__":
    main()
