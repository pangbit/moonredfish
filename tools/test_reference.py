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


# Explicit bounded extension; the original seven-route smoke check is unchanged.
HARDWARE_FILES = {
    "Systems/437XR1138R2/Processors/index.json": "6e0d2f3922ccc23de9ebd9bcdf75f6b8b64b01dee95e7432800971e1c7f40090",
    "Systems/437XR1138R2/Processors/CPU1/index.json": "9e36fe2d129b2534c7b33dcfeea9143cb582404dfb5bccb01f2c4801241e4975",
    "Systems/437XR1138R2/Processors/CPU2/index.json": "be797833f47b92b2ee59ac14f6e3992366c363ee95a9dca89523c5a3802ca971",
    "Systems/437XR1138R2/Processors/FPGA1/index.json": "be58bcd1666c5c21018bf51a73ce0abea1b29a96b09bdd3f4f3e8fdc5e4813e5",
    "Systems/437XR1138R2/Memory/index.json": "9c4c62f38603d5509f956f414bd10c03506bc0c7860b6ac31f53db889139d75d",
    "Systems/437XR1138R2/Memory/DIMM1/index.json": "b5188536e9eb8aaafbeb29c2adfcfcc111f8a1edadba2fc5de0d3f4ccc9e0cdf",
    "Systems/437XR1138R2/Memory/DIMM2/index.json": "9c25e78847fa81729ff6b663f6b8418925fb00398f8647504d8cc663ccc32315",
    "Systems/437XR1138R2/Memory/DIMM3/index.json": "713cc8f2e0fc520c7ba2d6f172cba28dbe41dad6e7cf74e30a7574037a30229a",
    "Systems/437XR1138R2/Memory/DIMM4/index.json": "3fa60ef801d5312e782cdaa5082a1527621eb0fb6fa455698fb17f70b6adeedc",
    "Chassis/1U/Thermal/index.json": "6af45ed3fd256fe9008f178ebc8ed301685ec6c9472680200c974edba1a491bd",
    "Chassis/1U/Power/index.json": "e6c2ec95e06cabc5c2bccb12579b64f62c2958dc0fcde7ad243768461a290298",
}


def load_routes(expanded=False):
    """Load 7 baseline inputs, or 18 with bounded hardware coverage, in memory."""
    routes = {}
    for name, digest in (FILES | HARDWARE_FILES if expanded else FILES).items():
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
