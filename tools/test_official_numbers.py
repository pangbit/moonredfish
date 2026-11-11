#!/usr/bin/env python3
"""Same-wire numeric observations; generic official readers are not typed parity oracles."""
import argparse
import ctypes
import hashlib
import json
import platform
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import urlparse

from test_gofish import ENV, REPO, ROOT, fixture, run_adapter
from test_pcie import make_cases as pcie_cases
from test_task import make_cases as task_cases

PINS = {"redfishtool": "8c46f567aa9c960851108e43bf23fd6a64c37897", "libredfish": "f9a23c33d46afe15f09b604160c09a320f1c769c", "jansson": "684e18c927e89615c2d501737e90018f4930d6c5"}


def pinned(path, name):
    actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=path, text=True).strip()
    assert actual == PINS[name], (name, actual)
    assert not subprocess.check_output(["git", "status", "--porcelain"], cwd=path, text=True).strip(), name + " source changed"


def json_type(val):
    return "null" if val is None else "boolean" if isinstance(val, bool) else "integer" if isinstance(val, int) else "real" if isinstance(val, float) else "string" if isinstance(val, str) else "array" if isinstance(val, list) else "object"


def selected(raw, path):
    for key in path:
        raw = raw[key]
    return {"json_type": json_type(raw), "value": raw}


class OfficialPayload:
    def __init__(self, path):
        self.lib = ctypes.CDLL(str(path))
        self.free = ctypes.CDLL(None).free
        self.free.argtypes = [ctypes.c_void_p]
        self.free.restype = None
        signatures = {
            "createRedfishPayloadFromString": ([ctypes.c_char_p, ctypes.c_void_p], ctypes.c_void_p),
            "getPayloadByNodeNameNoNetwork": ([ctypes.c_void_p, ctypes.c_char_p], ctypes.c_void_p),
            "payloadToString": ([ctypes.c_void_p, ctypes.c_bool], ctypes.c_void_p),
            "getPayloadIntValue": ([ctypes.c_void_p], ctypes.c_int),
            "getPayloadLongLongValue": ([ctypes.c_void_p], ctypes.c_longlong),
            "getPayloadDoubleValue": ([ctypes.c_void_p, ctypes.POINTER(ctypes.c_bool)], ctypes.c_double),
            "getPayloadBoolValue": ([ctypes.c_void_p, ctypes.POINTER(ctypes.c_bool)], ctypes.c_bool),
            "cleanupPayload": ([ctypes.c_void_p], None),
        }
        for name, (args, result) in signatures.items():
            fn = getattr(self.lib, name); fn.argtypes = args; fn.restype = result

    def observe(self, wire, path):
        root = self.lib.createRedfishPayloadFromString(wire, None)
        assert root, "official payload parser rejected synthetic input"
        pointers = [root]
        try:
            serialized = self.lib.payloadToString(root, False)
            assert serialized
            try:
                raw = json.loads(ctypes.string_at(serialized))
            finally:
                self.free(serialized)
            result = {"parsed": selected(raw, path)}
            for key in path:
                child = self.lib.getPayloadByNodeNameNoNetwork(pointers[-1], key.encode())
                assert child, key
                pointers.append(child)
            leaf = pointers[-1]
            is_real, is_bool = ctypes.c_bool(), ctypes.c_bool()
            result["accessors"] = {
                "int": self.lib.getPayloadIntValue(leaf),
                "long_long": self.lib.getPayloadLongLongValue(leaf),
                "double": self.lib.getPayloadDoubleValue(leaf, ctypes.byref(is_real)),
                "is_double": is_real.value,
                "boolean": self.lib.getPayloadBoolValue(leaf, ctypes.byref(is_bool)),
                "is_boolean": is_bool.value,
            }
            return result
        finally:
            for pointer in reversed(pointers):
                self.lib.cleanupPayload(pointer)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("redfishtool", "libredfish", "jansson", "python", "library"):
        parser.add_argument("--" + name, required=True, type=Path)
    parser.add_argument("--report", type=Path); args = parser.parse_args()
    for name in PINS:
        pinned(getattr(args, name), name)
    payload = OfficialPayload(args.library)
    # Select concrete previously asserted differences, without using their reports as outputs.
    groups = [("pcie", pcie_cases(), {"lane_float32_rounding", "lane_string", "lane_invalid_string", "lane_fraction", "lane_bool"}, ["PCIeInterface", "LanesInUse"]),
              ("task", task_cases(), {"percent_decimal_integer", "percent_above_native_range", "percent_above_schema_range"}, ["PercentComplete"])]
    records = []
    with tempfile.TemporaryDirectory(prefix="moonredfish-official-adapter-") as tmp:
        binary = Path(tmp) / "gofish-compare"
        subprocess.run(["go", "build", "-mod=readonly", "-o", str(binary), "."], cwd=REPO / "tools/gofish", env=ENV, check=True, timeout=180)
        for mode, (cases, routes), names, path in groups:
            cases = [c for c in cases if c["id"] in names]
            assert {c["id"] for c in cases} == names, (mode, names - {c["id"] for c in cases})
            manifest = ROOT + ("/PCIeTests" if mode == "pcie" else "/TaskTests")
            routes[manifest] = {"Cases": [{"ID": c["id"], "Kind": c["kind"], "URI": c["uri"]} for c in cases]}
            wires = {c["id"]: json.dumps(c["input"]).encode() for c in cases}
            for case in cases:
                routes[case["uri"]] = wires[case["id"]]
            outputs, requests = {}, {}
            for client, command in {"moonredfish": ["moon", "run", "examples/compare", "--target", "native", "--"], "gofish": [str(binary)]}.items():
                with fixture(routes) as (endpoint, state):
                    outputs[client] = run_adapter(client, command, mode, endpoint)["cases"]
                    for case in cases:
                        assert outputs[client][case["id"]] == case["expected"][client]
                    expected = ([ROOT + "/"] if client == "gofish" else []) + [manifest] + [c["uri"] for c in cases]
                    assert state["requests"] == [["GET", uri] for uri in expected] and not state["unexpected"] and state["login"] == state["logout"] == 0
                    requests[client] = state["requests"]
            official, official_requests = {}, []
            with fixture(routes) as (endpoint, state):
                host = urlparse(endpoint).netloc
                assert urlparse(endpoint).hostname == "127.0.0.1" and urlparse(endpoint).scheme == "http"
                for case in cases:
                    command = [str(args.python), str(args.redfishtool / "redfishtool.py"), "-r", host, "-A", "None", "-S", "Never", "-n", "-N", "raw", "GET", case["uri"]]
                    response = subprocess.run(command, env=ENV, capture_output=True, text=True, check=True, timeout=30)
                    official[case["id"]] = selected(json.loads(response.stdout), path)
                    assert official[case["id"]] == selected(case["input"], path)
                assert state["requests"] == [["GET", c["uri"]] for c in cases]
                assert not state["unexpected"] and state["login"] == state["logout"] == 0
                official_requests = state["requests"]
            for case in cases:
                ident = case["id"]; lib = payload.observe(wires[ident], path)
                expected = selected(case["input"], path); val = expected["value"]; typ = expected["json_type"]
                assert lib["parsed"] == expected
                assert lib["accessors"] == {"int": ctypes.c_int(val).value if typ == "integer" else 0,
                    "long_long": val if typ == "integer" else 0, "double": val if typ == "real" else 0.0,
                    "is_double": typ == "real", "boolean": val if typ == "boolean" else False, "is_boolean": typ == "boolean"}
                records.append({"id": ident, "mode": mode, "property_path": path, "wire_utf8": wires[ident].decode(),
                    "wire_sha256": hashlib.sha256(wires[ident]).hexdigest(), "input": expected,
                    "moonredfish": outputs["moonredfish"][ident], "gofish": outputs["gofish"][ident],
                    "redfishtool_raw_get": official[ident], "libredfish_payload": lib,
                    "classification": "generic official read observed; typed PCIe/Task validation/coercion coverage not established; exception unresolved"})
            print(mode + ": same-wire official raw GET and payload/accessor observations checked; typed coverage remains open")
            requests["redfishtool"] = official_requests; requests["libredfish"] = []
            for record in records:
                if record["mode"] == mode:
                    record["request_sequences_for_group"] = requests
    paths = ("tools/test_official_numbers.py", "tools/test_pcie.py", "tools/test_task.py", "tools/test_gofish.py", "tools/gofish/main.go", "examples/compare/main.mbt")
    report = {"subject_base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
        "reference_pins": {"gofish": "4cc897fb5c172996e8f34a31a5d1012b45a287a7", **PINS},
        "environment": {"os": platform.system(), "arch": platform.machine(), "python": subprocess.check_output([str(args.python), "--version"], text=True).strip(),
            "python_dependencies": subprocess.check_output([str(args.python), "-m", "pip", "freeze"], text=True).splitlines(),
            "go": subprocess.check_output(["go", "version"], text=True).strip(), "compiler": subprocess.check_output(["cc", "--version"], text=True).splitlines()[0],
            "cmake": subprocess.check_output(["cmake", "--version"], text=True).splitlines()[0]},
        "entry_points": {"redfishtool": "CLI raw GET; anonymous numeric loopback HTTP, no proxy/debug/polling", "libredfish": "createRedfishPayloadFromString + getPayloadByNodeNameNoNetwork + public numeric accessors; service=NULL, no network"},
        "scope": "Eight exact synthetic numeric inputs through real pinned implementations. No complete typed-property contract equivalence or verified GoFish defect exception; no real hardware, credentials, writes or publication.",
        "cases": records, "verified_exceptions": 0, "libredfish_binary_sha256": hashlib.sha256(args.library.read_bytes()).hexdigest(),
        "source_sha256": {n: hashlib.sha256((REPO / n).read_bytes()).hexdigest() for n in paths}}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(str(len(records)) + " same-input observations; zero verified typed-behavior exceptions")


if __name__ == "__main__":
    main()
