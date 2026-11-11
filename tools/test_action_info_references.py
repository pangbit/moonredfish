#!/usr/bin/env python3
"""Two GET-only GoFish reproductions plus pinned official source coverage audit; no exception oracle."""
import argparse
import hashlib
import json
import platform
import re
import subprocess
import tempfile
from pathlib import Path

from test_gofish import ENV, REPO, ROOT, fixture, run_adapter
from test_parity import error, ok, value
from test_action_info import project
from test_official_numbers import PINS, pinned


def source_coverage(path, name):
    pinned(path, name)
    roots = ["redfishtoollib"] if name == "redfishtool" else ["include", "src"]
    names = subprocess.check_output(["git", "ls-files", *roots], cwd=path, text=True).splitlines()
    names = [n for n in names if Path(n).suffix in (".py", ".c", ".h")]
    hits, hashes = {}, {}
    pattern = re.compile(r"ActionInfo|action_info|VirtualMedia|virtual_media|EjectMedia|ejectMedia|InsertMedia|insertMedia")
    for name in names:
        body = (path / name).read_bytes(); hashes[name] = hashlib.sha256(body).hexdigest()
        found = [{"line": i, "tokens": pattern.findall(line)} for i, line in enumerate(body.decode().splitlines(), 1) if pattern.search(line)]
        if found: hits[name] = found
    return {"scan_roots": roots, "source_sha256": hashes, "token_hits": hits,
            "coverage": "No VirtualMedia eject/insert ActionInfo selector found in reviewed fixed sources. Generic APIs do not establish equivalent behavior; no official runtime claim."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--redfishtool", required=True, type=Path)
    parser.add_argument("--libredfish", required=True, type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    coverage = {name: source_coverage(getattr(args, name), name) for name in ("redfishtool", "libredfish")}
    # The exact pinned sources have only generic ActionInfo handling in Redfishtool,
    # and no ActionInfo/VirtualMedia symbols in the reviewed libredfish headers/C files.
    assert not coverage["libredfish"]["token_hits"]
    assert set(coverage["redfishtool"]["token_hits"]) == {"redfishtoollib/Systems.py", "redfishtoollib/Managers.py", "redfishtoollib/redfishtoolTransport.py"}
    assert all(t in ("ActionInfo", "action_info") for hits in coverage["redfishtool"]["token_hits"].values() for hit in hits for t in hit["tokens"])
    prefix = ROOT + "/ActionInfoRoutingTests"
    insert, eject = prefix + "/Metadata/Insert", prefix + "/Metadata/Eject"
    routes = {ROOT + "/": {"Id": "RootService"}, insert: {"@odata.id": insert, "Id": "Insert", "Parameters": []}, eject: {"@odata.id": eject, "Id": "Eject", "Parameters": []}}
    cases = []
    for ident, actions, expected, gets in (
        ("both_distinct", {"#VirtualMedia.InsertMedia": {"@Redfish.ActionInfo": insert}, "#VirtualMedia.EjectMedia": {"@Redfish.ActionInfo": eject}}, ok(value(project(routes[insert], "gofish"))), [insert]),
        ("eject_only", {"#VirtualMedia.EjectMedia": {"@Redfish.ActionInfo": eject}}, error("unsupported"), []),
    ):
        uri = prefix + "/Cases/" + ident
        routes[uri] = {"@odata.id": uri, "Id": ident, "Actions": actions}
        cases.append({"id": ident, "uri": uri, "input": routes[uri], "expected": expected, "gets": [uri, *gets]})
    routes[prefix] = {"Cases": [{"ID": c["id"], "URI": c["uri"], "Kind": "eject_info"} for c in cases]}
    with tempfile.TemporaryDirectory(prefix="moonredfish-action-routing-") as tmp:
        binary = Path(tmp) / "gofish-compare"
        subprocess.run(["go", "build", "-mod=readonly", "-o", str(binary), "."], cwd=REPO / "tools/gofish", env=ENV, check=True, timeout=180)
        with fixture(routes) as (endpoint, state):
            output = run_adapter("gofish", [str(binary)], "action-info-routing", endpoint)["cases"]
            assert set(output) == {c["id"] for c in cases}
            for case in cases:
                assert output[case["id"]] == case["expected"]
            expected_requests = [["GET", p] for p in [ROOT + "/", prefix, *(p for c in cases for p in c["gets"])]]
            assert state["requests"] == expected_requests
            assert not state["unexpected"] and state["login"] == state["logout"] == 0
            requests = state["requests"]
    paths = ("tools/test_action_info_references.py", "tools/test_action_info.py", "tools/test_official_numbers.py", "tools/test_gofish.py", "tools/gofish/action_info.go", "tools/gofish/main.go")
    report = {"subject_base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
              "reference_pins": {"gofish": "4cc897fb5c172996e8f34a31a5d1012b45a287a7", **{n: PINS[n] for n in coverage}},
              "environment": {"os": platform.system(), "arch": platform.machine(), "go": subprocess.check_output(["go", "version"], text=True).strip()},
              "operation": "Actual GoFish VirtualMedia.EjectMediaActionInfo GET-only reproduction; official source coverage audit, not official runtime behavior",
              "cases": [{**{k: v for k, v in c.items() if k != "expected"}, "observed_gofish": output[c["id"]]} for c in cases],
              "gofish_requests": requests, "official_source_coverage": coverage, "verified_exceptions": 0,
              "gate_result": "Unmet: both pinned official references lack an established comparable VirtualMedia ActionInfo selector. Generic URI/node lookup is not evidence for selector semantics. No exception, workaround or EjectMediaActionInfo compatibility method implemented.",
              "source_sha256": {p: hashlib.sha256((REPO / p).read_bytes()).hexdigest() for p in paths}}
    if args.report: args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print("2 GoFish routing reproductions passed; both official coverage gaps recorded; zero verified exceptions")


if __name__ == "__main__":
    main()
