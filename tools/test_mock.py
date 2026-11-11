#!/usr/bin/env python3
"""Local synthetic HTTP integration. No BMC, network inventory, or real credentials."""
import json
import os
import ssl
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = "/redfish/v1"
TOKEN = "synthetic-token-not-a-secret"
STATE = {"login": 0, "logout": 0, "authenticated": 0, "unexpected": [], "fail_systems": False, "require_auth": False, "logout_retries": 0, "unsafe_session_target": False}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def respond(self, code, data, **headers):
        payload = data if isinstance(data, bytes) else json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        for key, value in headers.items():
            self.send_header(key.replace("_", "-"), value)
        self.end_headers()
        try:
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_POST(self):
        # The official HTTP client streams JSON using chunked transfer encoding.
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            chunks = []
            while True:
                size = int(self.rfile.readline().strip(), 16)
                if not size:
                    self.rfile.readline()
                    break
                chunks.append(self.rfile.read(size))
                self.rfile.read(2)
            data = b"".join(chunks)
        else:
            data = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        collection = ROOT + ("/SessionService/Sessions" if STATE["require_auth"] else "/Sessions")
        assert self.path == collection
        credentials = json.loads(data)
        if credentials.get("Password") == "synthetic-wrong":
            return self.respond(401, {})
        assert credentials.get("Password") == "synthetic-password"
        username = credentials.get("UserName")
        assert username in ("synthetic-user", "synthetic-retry", "synthetic-expired", "synthetic-slow")
        ident = {"synthetic-retry": "retry", "synthetic-expired": "expired", "synthetic-slow": "slow"}.get(username, "1")
        STATE["login"] += 1
        if ident == "slow":
            time.sleep(0.08)
        self.respond(201, {}, X_Auth_Token=TOKEN, Location=collection + "/" + ident)

    def do_DELETE(self):
        assert self.path in [ROOT + prefix + ident for prefix in ("/SessionService/Sessions/", "/Sessions/") for ident in ("1", "retry", "expired", "slow")]
        assert self.headers.get("X-Auth-Token") == TOKEN
        if self.path.endswith("/retry") and STATE["logout_retries"] == 0:
            STATE["logout_retries"] += 1
            return self.respond(503, {})
        STATE["logout"] += 1
        self.respond(404 if self.path.endswith("/expired") else 204, b"")

    def do_GET(self):
        assert self.headers.get("Accept") == "application/json"
        if STATE["require_auth"] and self.headers.get("X-Auth-Token") != TOKEN:
            return self.respond(401, {})
        if self.headers.get("X-Auth-Token") == TOKEN:
            STATE["authenticated"] += 1
        p = self.path
        if p == ROOT + "/":
            return self.respond(200, {**{kind: {"@odata.id": ROOT + "/" + kind} for kind in ("Systems", "Chassis", "Managers")}, "Links": {"Sessions": {"@odata.id": ROOT + ("/Systems" if STATE["unsafe_session_target"] else "/Sessions")}}})
        if p == ROOT + "/Systems" and STATE["fail_systems"]:
            return self.respond(403, {"error": {"message": "synthetic private body"}})
        if p == ROOT + "/Systems":
            return self.respond(200, {"Members": [{"@odata.id": ROOT + "/Systems/1"}], "Members@odata.nextLink": ROOT + "/Systems?$skip=1"})
        if p == ROOT + "/Systems?$skip=1":
            return self.respond(200, {"Members": [{"@odata.id": ROOT + "/Systems/1"}, {"@odata.id": ROOT + "/Systems/2"}]})
        if p in (ROOT + "/Chassis", ROOT + "/Managers"):
            return self.respond(200, {"Members": [{"@odata.id": p + "/1"}]})
        if p in [ROOT + "/" + kind + "/" + ident for kind in ("Systems", "Chassis", "Managers") for ident in ("1", "2")]:
            return self.respond(200, {"Id": p.rsplit("/", 1)[1], "Name": "Synthetic resource"})
        if p == ROOT + "/Inventory/Processors":
            return self.respond(200, {"Members": [{"@odata.id": ROOT + "/Inventory/Processors/0"}], "Members@odata.nextLink": ROOT + "/Inventory/Processors?$skip=1"})
        if p == ROOT + "/Inventory/Processors?$skip=1":
            return self.respond(200, {"Members": [{"@odata.id": ROOT + "/Inventory/Processors/0"}, {"@odata.id": ROOT + "/Inventory/Processors/1"}]})
        if p in (ROOT + "/Inventory/Processors/0", ROOT + "/Inventory/Processors/1"):
            return self.respond(200, {"Id": p.rsplit("/", 1)[1], "TotalCores": 0, "Model": "Synthetic CPU"})
        if p == ROOT + "/Inventory/Empty":
            return self.respond(200, {"Members": []})
        if p == ROOT + "/Inventory/Broken":
            return self.respond(200, {"Members": [{"@odata.id": ROOT + "/Inventory/Processors/0"}, {"@odata.id": ROOT + "/Inventory/Missing"}]})
        if p == ROOT + "/Inventory/Missing":
            return self.respond(404, {})
        if p == ROOT + "/Forbidden":
            return self.respond(403, {"error": {"code": "Base.1.0.GeneralError", "message": "synthetic private body", "@Message.ExtendedInfo": [{"MessageId": "Base.1.0.InsufficientPrivilege", "MessageArgs": ["synthetic-password"]}]}})
        if p == ROOT + "/Redirect":
            return self.respond(302, {}, Location="https://example.invalid/never-follow")
        if p == ROOT + "/Invalid":
            return self.respond(200, b"not JSON")
        if p == ROOT + "/Cycle":
            return self.respond(200, {"Members": [], "Members@odata.nextLink": p})
        if p == ROOT + "/Unsafe":
            return self.respond(200, {"Members": [{"@odata.id": "https://example.invalid/never-follow"}]})
        if p.startswith(ROOT + "/SlowPages?page="):
            page = int(p.rsplit("=", 1)[1])
            time.sleep(0.06)
            body = {"Members": []}
            if page < 3:
                body["Members@odata.nextLink"] = ROOT + f"/SlowPages?page={page + 1}"
            return self.respond(200, body)
        if p == ROOT + "/Slow":
            time.sleep(0.15)
            return self.respond(200, {})
        STATE["unexpected"].append(p)
        self.respond(404, {})


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        with tempfile.TemporaryDirectory(prefix="moonredfish-test-") as tmp:
            cert = Path(tmp) / "cert.pem"
            key = Path(tmp) / "key.pem"
            config = Path(tmp) / "openssl.cnf"
            config.write_text("[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n[dn]\nCN=not-localhost.example.invalid\n[ext]\nsubjectAltName=IP:127.0.0.1\nbasicConstraints=critical,CA:TRUE\n")
            subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-config", str(config), "-keyout", str(key), "-out", str(cert)], check=True, capture_output=True)
            tls_server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(cert, key)
            tls_server.socket = context.wrap_socket(tls_server.socket, server_side=True)
            threading.Thread(target=tls_server.serve_forever, daemon=True).start()
            try:
                subprocess.run(["moon", "run", "examples/integration", "--target", "native", "--", f"http://127.0.0.1:{server.server_port}", f"https://127.0.0.1:{tls_server.server_port}", str(cert), f"https://localhost:{tls_server.server_port}"], cwd=Path(__file__).resolve().parents[1], env={**os.environ, "RUST_LOG": "error"}, check=True, timeout=120)
                # Exercise the actual authenticated application, including error cleanup.
                command = ["moon", "run", "examples/session_inventory", "--target", "native", "--", f"https://127.0.0.1:{tls_server.server_port}"]
                environment = {**os.environ, "RUST_LOG": "error", "REDFISH_USERNAME": "synthetic-user", "REDFISH_PASSWORD": "synthetic-password", "REDFISH_CA_FILE": str(cert)}
                STATE["require_auth"] = True
                success = subprocess.run(command, cwd=Path(__file__).resolve().parents[1], env=environment, capture_output=True, text=True, timeout=120)
                assert success.returncode == 0, success.stderr
                assert "inventory: systems=2, chassis=1, managers=1" in success.stdout
                hardware = subprocess.run(["moon", "run", "examples/hardware", "--target", "native", "--", f"https://127.0.0.1:{tls_server.server_port}"], cwd=Path(__file__).resolve().parents[1], env=environment, capture_output=True, text=True, timeout=120)
                assert hardware.returncode == 0, "hardware HTTPS example failed"
                assert "processor_count=missing, processors=missing, memory=missing" in hardware.stdout
                assert "thermal subsystem: missing" in hardware.stdout
                STATE["fail_systems"] = True
                try:
                    failure = subprocess.run(command, cwd=Path(__file__).resolve().parents[1], env=environment, capture_output=True, text=True, timeout=120)
                finally:
                    STATE["fail_systems"] = False
                    STATE["require_auth"] = False
                assert failure.returncode != 0, "expected the inventory read to fail"
                assert "HTTP 403" in failure.stdout + failure.stderr, "expected an HTTP permission failure"
                combined = success.stdout + success.stderr + failure.stdout + failure.stderr + hardware.stdout + hardware.stderr
                for secret in ("synthetic-password", TOKEN, "synthetic private body"):
                    assert secret not in combined, "application output leaked sensitive input"
                before_login = STATE["login"]
                STATE["unsafe_session_target"] = True
                try:
                    blocked = subprocess.run(command, cwd=Path(__file__).resolve().parents[1], env=environment, capture_output=True, text=True, timeout=120)
                finally:
                    STATE["unsafe_session_target"] = False
                assert blocked.returncode != 0 and "InvalidResponse" in blocked.stderr + blocked.stdout
                assert STATE["login"] == before_login, "unsafe session discovery sent a POST"
                assert STATE["login"] == STATE["logout"] == 10, STATE
                assert STATE["authenticated"] > 0, STATE
                assert not STATE["unexpected"], STATE
                print("mock server: authenticated example, success/error cleanup, redaction and expected paths verified")
            finally:
                tls_server.shutdown()
                tls_server.server_close()
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
