#!/usr/bin/env python3
"""Read-only compatibility test against seven pinned DMTF public mockup files.

Upstream bytes are hash-checked, served unchanged (including copyright fields),
and kept only in memory. They are not vendored or included in this package.
See docs/REFERENCE.md for scope, provenance and upstream copyright conditions.
"""
import hashlib
import os
import subprocess
import threading
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

COMMIT = "23d21f9a3610f6b6fbb71ffc941296b159a524d2"
BASE = f"https://raw.githubusercontent.com/DMTF/Redfish-Mockup-Server/{COMMIT}/public-rackmount1/"
FILES = {
    "index.json": "3cdbdf2c7bc87d35b4fe7124be221da3e846f1815ebb963178f039114a55383e",
    "Systems/index.json": "4dd474ce66cd7e11426d781c706dc8c31aff50f8bf57f64dfea8e7eee3f0b765",
    "Systems/437XR1138R2/index.json": "af03202a1bcd4f16ee8dab92364fc7b1f78cb3088f74d3b79294e9c22ee2957b",
    "Chassis/index.json": "25f4c999e0d60d114a8ca3afcc328bd906bdc38984015903ad620e6135e905b2",
    "Chassis/1U/index.json": "654fa8d2b0127801b36dd12ce61666aea67649d07a4e1222d815f0e3edb77993",
    "Managers/index.json": "c35eb1632da0d34e801e9dead2584c9809336086662a9bc53920846dd56532cb",
    "Managers/BMC/index.json": "ff81171119d4637e7af5398913aec5a70ac0c0f6dbeee3e0aa19f4847dd11582",
}


def load_routes():
    """Load unchanged hash-checked inputs for either independent client check."""
    routes = {}
    for name, digest in FILES.items():
        with urllib.request.urlopen(BASE + name, timeout=20) as response:
            data = response.read(65537)
        if len(data) > 65536 or hashlib.sha256(data).hexdigest() != digest:
            raise RuntimeError(f"pinned mockup integrity check failed: {name}")
        suffix = name.removesuffix("index.json").rstrip("/")
        routes["/redfish/v1/" + suffix if suffix else "/redfish/v1/"] = data
    return routes


def main():
    routes = load_routes()
    visited = set()
    unexpected = []

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            data = routes.get(self.path)
            if data is None:
                unexpected.append(self.path)
                data = b"{}"
                self.send_response(404)
            else:
                visited.add(self.path)
                self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_POST(self):
            unexpected.append("POST")
            self.send_error(405)

        def do_DELETE(self):
            unexpected.append("DELETE")
            self.send_error(405)

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        subprocess.run(
            ["moon", "run", "examples/reference", "--target", "native", "--", f"http://127.0.0.1:{server.server_port}"],
            cwd=Path(__file__).resolve().parents[1], env={**os.environ, "RUST_LOG": "error"}, check=True, timeout=120,
        )
        assert visited == set(routes), "not every selected upstream fixture was read"
        assert not unexpected, "unexpected resource path or mutating request"
        print(f"reference source: DMTF/Redfish-Mockup-Server@{COMMIT}; 7 hashes verified")
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
