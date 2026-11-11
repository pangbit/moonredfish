#!/usr/bin/env python3
"""Bounded read-only differential evidence; known differences are not parity passes."""
import argparse
from collections import Counter
import hashlib
import json
import platform
import subprocess
import tempfile
from pathlib import Path

from test_gofish import ENV, REPO, ROOT, fixture, run_adapter

PREFIX = ROOT + "/Parity"
MISSING = {"state": "missing"}
NULL = {"state": "null"}
NIL = {"state": "nil"}


def value(data):
    return {"state": "value", "value": data}


def ok(data):
    return {"ok": True, "error": "", "value": data}


def error(category, data=None):
    return {"ok": False, "error": category, "value": data}


def cases_and_routes():
    routes = {ROOT + "/": {"Id": "RootService"}}
    cases = []

    def add(ident, body, moon, go, field="CapacityBytes", kind="drive", behavior="B08", moon_gets=(), go_gets=()):
        uri = PREFIX + "/Cases/" + ident
        raw = body if isinstance(body, bytes) else json.dumps(body).encode()
        routes[uri] = raw
        cases.append({"id": ident, "uri": uri, "field": field, "kind": kind, "behavior": behavior,
                      "sha256": hashlib.sha256(raw).hexdigest(), "moonredfish": moon, "gofish": go,
                      "requests": {"moonredfish": [uri, *moon_gets], "gofish": [uri, *go_gets]}})

    def number(ident, token, moon, go):
        add(ident, ('{"CapacityBytes":' + token + '}').encode(), moon, go)

    invalid = error("invalid_response")
    typed = error("json_type")
    add("capacity_missing", {}, ok(MISSING), ok(NIL), behavior="B07")
    add("capacity_null", {"CapacityBytes": None}, ok(NULL), ok(NIL), behavior="B07")
    number("capacity_zero", "0", ok(value(0)), ok(value(0)))
    number("capacity_safe_max", "9007199254740991", ok(value(9007199254740991)), ok(value(9007199254740991)))
    number("capacity_above_safe", "9007199254740992", invalid, ok(value(9007199254740992)))
    number("capacity_int64_max", "9223372036854775807", invalid, ok(value(9223372036854775807)))
    number("capacity_int64_overflow", "9223372036854775808", invalid, typed)
    number("capacity_negative", "-1", invalid, ok(value(-1)))
    number("capacity_fraction", "1.5", invalid, typed)
    number("capacity_rounded_fraction", "1.0000000000000001", invalid, typed)
    number("capacity_large_fraction", "9007199254740991.1", invalid, typed)
    number("capacity_underflow", "1e-9999", invalid, typed)
    number("capacity_decimal_integer", "1.0", ok(value(1)), typed)
    number("capacity_exponent_integer", "1e3", ok(value(1000)), typed)
    number("capacity_string", '"1"', invalid, typed)
    add("boolean_false", {"FailurePredicted": False}, ok(value(False)), ok(value(False)), "FailurePredicted", behavior="B07")
    add("boolean_missing", {}, ok(MISSING), ok(value(False)), "FailurePredicted", behavior="B07")
    add("boolean_null", {"FailurePredicted": None}, ok(NULL), ok(value(False)), "FailurePredicted", behavior="B07")
    add("boolean_wrong_type", {"FailurePredicted": 0}, invalid, typed, "FailurePredicted", behavior="B09")
    add("enum_unknown", {"Protocol": "FutureProtocol"}, ok(value("FutureProtocol")), ok(value("FutureProtocol")), "Protocol", behavior="B07")
    add("enum_missing", {}, ok(MISSING), ok(value("")), "Protocol", behavior="B07")
    add("enum_null", {"Protocol": None}, ok(NULL), ok(value("")), "Protocol", behavior="B07")
    add("enum_wrong_type", {"Protocol": False}, invalid, typed, "Protocol", behavior="B09")
    add("duplicate_key", b'{"CapacityBytes":1,"CapacityBytes":2}', invalid, ok(value(2)), behavior="B09")
    add("case_folded_key", {"capacitybytes": 3}, ok(MISSING), ok(value(3)), behavior="B09")
    add("invalid_utf8", b'{"SerialNumber":"\xff"}', invalid, ok(value("\ufffd")), "SerialNumber", behavior="B09")
    add("trailing_json", b'{"CapacityBytes":1} {}', invalid, ok(value(1)), behavior="B09")

    add("truncated_json", b'{"CapacityBytes":', invalid, error("json_eof"), behavior="B09")
    add("malformed_json", b'{"CapacityBytes":!}', invalid, error("json_syntax"), behavior="B09")

    one, two, bad = (PREFIX + "/Members/" + name for name in ("1", "2", "Bad"))
    routes[one] = {"@odata.id": one, "Id": "1", "Name": "full one"}
    routes[two] = {"@odata.id": two, "Id": "2", "Name": "full two"}
    routes[bad] = (404, {})
    a, b = {"id": "1", "name": "full one"}, {"id": "2", "name": "full two"}
    link = lambda uri: {"@odata.id": uri}
    def collection(ident, body, moon, go, mg=(), gg=(), behavior="B05"):
        add(ident, body, moon, go, "", "collection", behavior, mg, gg)
    collection("collection_order", {"Members": [link(two), link(one)]}, ok([b, a]), ok([b, a]), [two, one], [two, one])
    collection("collection_duplicate", {"Members": [link(one), link(one)]}, ok([a]), ok([a, a]), [one], [one, one])
    collection("collection_embedded", {"Members": [{"@odata.id": one, "Id": "1", "Name": "inline one"}]},
               ok([a]), ok([{"id": "1", "name": "inline one"}]), [one], [], "B06")
    collection("collection_missing_members", {}, invalid, ok([]))
    collection("collection_null_members", {"Members": None}, invalid, ok([]))
    collection("collection_empty", {"Members": []}, ok([]), ok([]))
    collection("collection_unlinked_member", {"Members": [{}]}, invalid, ok([]))
    collection("collection_member_failure", {"Members": [link(one), link(bad)]}, error("http"), error("collection", [a]), [one, bad], [one, bad])
    next_uri = PREFIX + "/Pages/2"
    routes[next_uri] = {"Members": [link(two)]}
    collection("collection_paged", {"Members": [link(one)], "Members@odata.nextLink": next_uri},
               ok([a, b]), ok([a, b]), [next_uri, one, two], [next_uri, one, two])
    loop_uri = PREFIX + "/Cases/collection_cycle"
    collection("collection_cycle", {"Members": [link(one)], "Members@odata.nextLink": loop_uri},
               error("pagination_cycle"), error("collection", [a]), [], [one])
    routes[PREFIX] = {"Cases": [{"ID": c["id"], "URI": c["uri"], "Kind": c["kind"], "Field": c["field"]} for c in cases]}
    return cases, routes


def trace_cases(requests, cases):
    start = {c["uri"]: c["id"] for c in cases}
    out = {"startup": []}
    current = "startup"
    for method, uri in requests:
        assert method == "GET", "parity fixture must remain read-only"
        if uri in start:
            current = start[uri]
            assert current not in out, "case executed more than once"
            out[current] = []
        out[current].append(uri)
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, help="write observations and request sequences after assertions pass")
    args = parser.parse_args()
    assert platform.architecture()[0] == "64bit", "this evidence batch explicitly targets 64-bit Go int"
    cases, routes = cases_and_routes()
    reports = {}
    with tempfile.TemporaryDirectory(prefix="moonredfish-parity-") as tmp:
        binary = Path(tmp) / "gofish-compare"
        subprocess.run(["go", "build", "-mod=readonly", "-o", str(binary), "."], cwd=REPO / "tools/gofish", env=ENV, check=True, timeout=180)
        commands = {"moonredfish": ["moon", "run", "examples/compare", "--target", "native", "--"], "gofish": [str(binary)]}
        for name, command in commands.items():
            with fixture(routes) as (endpoint, state):
                actual = run_adapter(name, command, "parity", endpoint)["cases"]
                assert set(actual) == {c["id"] for c in cases}
                assert not state["unexpected"] and state["login"] == state["logout"] == 0
                traces = trace_cases(state["requests"], cases)
                assert traces["startup"] == ([ROOT + "/"] if name == "gofish" else []) + [PREFIX]
                for case in cases:
                    ident = case["id"]
                    assert actual[ident] == case[name], f"{name}: {ident}: {actual[ident]!r} != {case[name]!r}"
                    # Goroutine scheduling affects member GET order in GoFish. Preserve
                    # the actual sequence in evidence; assert multiplicity, not a fake order.
                    assert Counter(traces[ident]) == Counter(case["requests"][name]), f"{name}: {ident}: request multiplicity mismatch"
                reports[name] = {"observations": actual, "request_sequences": traces}
            print(f"{name}: {len(cases)} read-only observations and request multiplicities checked")
    relations = {}
    for case in cases:
        m, g = case["moonredfish"], case["gofish"]
        relation = "same_selected_observation" if m == g else "both_reject" if not m["ok"] and not g["ok"] and m["value"] == g["value"] else "known_difference"
        relations[case["id"]] = relation
    summary = dict(Counter(relations.values()))
    report = {"reference": {"version": "v0.27.0", "commit": "4cc897fb5c172996e8f34a31a5d1012b45a287a7"},
              "subject_base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
              "environment": {"os": platform.system(), "arch": platform.machine(), "go": subprocess.check_output(["go", "version"], text=True).strip(),
                              "moon": subprocess.check_output(["moon", "version", "--all"], env=ENV, text=True).strip()},
              "limits": "Synthetic read-only selected fields/collection behavior only; no approved API mapping, full error equivalence, safety-default equivalence, real BMC or all-platform claim. Same projection is not full item parity.",
              "summary": summary, "cases": [{"id": c["id"], "behavior": c["behavior"], "kind": c["kind"], "field": c["field"], "fixture_sha256": c["sha256"], "relation": relations[c["id"]]} for c in cases],
              "adapters": reports}
    for case in report["cases"]:
        if case["kind"] == "drive":
            case["item_ids"] = ["schemas::field::Drive." + case["field"],
                                "schemas::method::*Drive.UnmarshalJSON", "schemas::function::GetDrive",
                                "schemas::function::GetObject", "schemas::function::DecodeGenericEntity"]
        else:
            case["item_ids"] = ["schemas::function::GetCollectionObjects", "schemas::function::GetResourceCollection"]
            if case["id"] in ("collection_member_failure", "collection_cycle"):
                case["item_ids"] += ["schemas::type::CollectionError", "schemas::field::CollectionError.Failures"]
    report["source_sha256"] = {name: hashlib.sha256((REPO / name).read_bytes()).hexdigest() for name in (
        "moonredfish.mbt", "inventory_fields.mbt", "examples/compare/main.mbt", "examples/compare/parity.mbt", "tools/gofish/main.go", "tools/gofish/parity.go", "tools/test_gofish.py", "tools/test_parity.py")}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"Evidence categories: {summary}; no matrix row promoted to verified equivalence")


if __name__ == "__main__":
    main()
