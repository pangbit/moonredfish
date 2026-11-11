#!/usr/bin/env python3
"""Read-only DHCP/DNS/SLAAC feature verification against GoFish v0.27.0."""
import argparse
import hashlib
import json
import platform
import subprocess
import tempfile
from collections import Counter
from pathlib import Path

from test_gofish import ENV, REPO, ROOT, fixture, run_adapter
from test_parity import MISSING, NULL, NIL, error, ok, value

PREFIX = ROOT + "/NetworkConfig"
GROUPS = {
    "DHCPv4": ("DHCPv4Configuration", {"DHCPEnabled": False, "FallbackAddress": "", "UseDNSServers": False,
               "UseDomainName": False, "UseGateway": False, "UseNTPServers": False, "UseStaticRoutes": False}),
    "DHCPv6": ("DHCPv6Configuration", {"OperatingMode": "", "UseDNSServers": False, "UseDomainName": False,
               "UseNTPServers": False, "UseRapidCommit": False}),
    "StatelessAddressAutoConfig": ("StatelessAddressAutoConfiguration", {"IPv4AutoConfigEnabled": False, "IPv6AutoConfigEnabled": False}),
}
SCALARS = {"AutoNeg": False, "EthernetInterfaceType": "", "IPv6DefaultGateway": "", "IPv6Enabled": False,
           "RoutingScope": "", "TeamMode": "", "UefiDevicePath": ""}
ARRAYS = ("NameServers", "StaticNameServers")
FIELDS = (*SCALARS, *ARRAYS, *GROUPS)
FULL = {"AutoNeg": False, "EthernetInterfaceType": "Physical", "IPv6DefaultGateway": "2001:db8::1", "IPv6Enabled": True,
        "RoutingScope": "HostOnly", "TeamMode": "ActiveBackup", "UefiDevicePath": "synthetic-path",
        "NameServers": ["192.0.2.2", "2001:db8::53", "192.0.2.2"], "StaticNameServers": [],
        "DHCPv4": {"DHCPEnabled": False, "FallbackAddress": "Static", "UseDNSServers": True, "UseDomainName": False,
                   "UseGateway": True, "UseNTPServers": False, "UseStaticRoutes": True},
        "DHCPv6": {"OperatingMode": "Stateful", "UseDNSServers": False, "UseDomainName": True, "UseNTPServers": False, "UseRapidCommit": True},
        "StatelessAddressAutoConfig": {"IPv4AutoConfigEnabled": False, "IPv6AutoConfigEnabled": True}}


def expected(raw, client):
    """Explicit declared defaults and Field rules; never consumes adapter output."""
    def scalar(obj, key, default):
        if client == "moonredfish":
            return MISSING if key not in obj else NULL if obj[key] is None else value(obj[key])
        return value(default if obj.get(key) is None else obj[key])
    out = {key: scalar(raw, key, default) for key, default in SCALARS.items()}
    for key in ARRAYS:
        if raw.get(key) is None:
            out[key] = (MISSING if key not in raw else NULL) if client == "moonredfish" else NIL
        else:
            out[key] = value(raw[key] if client == "moonredfish" else ["" if item is None else item for item in raw[key]])
    for key, (_, fields) in GROUPS.items():
        if raw.get(key) is None and client == "moonredfish":
            out[key] = MISSING if key not in raw else NULL
        else:
            out[key] = value({name: scalar(raw.get(key) or {}, name, default) for name, default in fields.items()})
    return out


def make_cases():
    cases = []
    routes = {ROOT + "/": {"Id": "RootService"}}
    def add(ident, raw, fields=FIELDS, rejection=None, collection=False):
        uri = PREFIX + "/Cases/" + ident
        item_ids = []
        for path in fields:
            parent, _, child = path.partition(".")
            item_ids.append("schemas::field::" + (GROUPS[parent][0] + "." + child if child else "EthernetInterface." + parent))
            if parent in GROUPS:
                typename, members = GROUPS[parent]
                item_ids.append("schemas::type::" + typename)
                if not child:
                    item_ids += ["schemas::field::" + typename + "." + name for name in members]
        item_ids = list(dict.fromkeys(item_ids))
        item_ids += ["schemas::method::*EthernetInterface.UnmarshalJSON", "schemas::function::GetEthernetInterface"]
        outcomes = {client: ok(expected(raw, client)) for client in ("moonredfish", "gofish")}
        if rejection:
            outcomes["moonredfish"] = error("invalid_response")
            if rejection == "both":
                outcomes["gofish"] = error("json_type")
        if collection:
            routes[uri] = {"Id": ident, "EthernetInterfaces": {"@odata.id": uri + "/EthernetInterfaces"}}
            routes[uri + "/EthernetInterfaces"] = {"Members": [{"@odata.id": uri + "/EthernetInterfaces/0"}]}
            routes[uri + "/EthernetInterfaces/0"] = raw
            for client in outcomes:
                outcomes[client] = ok([outcomes[client]["value"]])
            item_ids += ["schemas::method::*ComputerSystem.EthernetInterfaces", "schemas::function::ListReferencedEthernetInterfaces"]
            paths = [uri, uri + "/EthernetInterfaces", uri + "/EthernetInterfaces/0"]
        else:
            routes[uri] = raw
            paths = [uri]
        cases.append({"id": ident, "uri": uri, "kind": "collection" if collection else "direct", "input": raw,
                      "item_ids": item_ids, "focus_fields": list(fields), "expected": outcomes, "paths": paths})
    add("defined_configuration", FULL, collection=True)
    add("all_missing", {})
    add("all_null", {k: None for k in FIELDS})
    add("empty_nested_objects", {k: {} for k in GROUPS}, GROUPS)
    add("nested_nulls", {k: {f: None for f in fs} for k, (_, fs) in GROUPS.items()},
        [k+"."+f for k, (_, fs) in GROUPS.items() for f in fs])
    add("unknown_policy_strings", {"EthernetInterfaceType": "FutureInterface", "RoutingScope": "FutureScope", "TeamMode": "FutureTeam",
        "DHCPv4": {"FallbackAddress": "FutureFallback"}, "DHCPv6": {"OperatingMode": "FutureMode"}},
        ["EthernetInterfaceType", "RoutingScope", "TeamMode", "DHCPv4.FallbackAddress", "DHCPv6.OperatingMode"])
    add("ipv6_present_without_enabled", {"IPv6DefaultGateway": "2001:db8::1"}, ["IPv6DefaultGateway", "IPv6Enabled"])
    add("team_mode_absent", {"AutoNeg": True}, ["TeamMode"])
    for key, default in SCALARS.items():
        add("wrong_" + key, {key: "false" if isinstance(default, bool) else False}, [key], rejection="both")
    for key in ARRAYS:
        add("wrong_" + key, {key: "192.0.2.53"}, [key], rejection="both")
        add("wrong_element_" + key, {key: [123]}, [key], rejection="both")
        add("null_element_" + key, {key: [None]}, [key], rejection="moon")
        add("empty_" + key, {key: []}, [key])
    for group, (_, fields) in GROUPS.items():
        add("wrong_" + group, {group: False}, [group], rejection="both")
        for key, default in fields.items():
            add("wrong_" + group + "_" + key, {group: {key: "false" if isinstance(default, bool) else False}}, [group+"."+key], rejection="both")
    routes[PREFIX] = {"Cases": [{"ID": c["id"], "URI": c["uri"], "Kind": c["kind"]} for c in cases]}
    return cases, routes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    cases, routes = make_cases()
    observed = {}
    with tempfile.TemporaryDirectory(prefix="moonredfish-network-") as tmp:
        binary = Path(tmp) / "gofish-compare"
        subprocess.run(["go", "build", "-mod=readonly", "-o", str(binary), "."], cwd=REPO / "tools/gofish", env=ENV, check=True, timeout=180)
        commands = {"moonredfish": ["moon", "run", "examples/compare", "--target", "native", "--"], "gofish": [str(binary)]}
        for client, command in commands.items():
            with fixture(routes) as (endpoint, state):
                result = run_adapter(client, command, "network-config", endpoint)["cases"]
                assert result == {c["id"]: c["expected"][client] for c in cases}, client + ": network observations differ from explicit expectations"
                expected_paths = ([ROOT + "/"] if client == "gofish" else []) + [PREFIX] + [path for c in cases for path in c["paths"]]
                assert state["requests"] == [["GET", path] for path in expected_paths], client + ": unexpected request sequence"
                assert not state["unexpected"] and state["login"] == state["logout"] == 0
                observed[client] = {"observations": result, "requests": state["requests"]}
            print(f"{client}: DHCPv4/DHCPv6/SLAAC, DNS and interface policy reads verified for declared cases")
    matrix = json.loads((REPO / "docs/gofish/api-v0.27.0.json").read_text())
    row_ids = {f["package"]+"::"+r["kind"]+"::"+r["name"] for f in matrix["files"] for r in f["symbols"]}
    for case in cases:
        assert set(case["item_ids"]) <= row_ids
        m, g = (case["expected"][client] for client in ("moonredfish", "gofish"))
        case["relation"] = "same_selected_observation" if m == g else "both_reject" if not m["ok"] and not g["ok"] else "known_difference"
        case["fixture_sha256"] = hashlib.sha256(json.dumps(case["input"]).encode()).hexdigest()
    # Assert the complete projection above; retain focused, unchanged fields in
    # evidence instead of repeating unrelated defaults in every wrong-type case.
    for client, data in observed.items():
        for case in cases:
            outcome = data["observations"][case["id"]]
            if outcome["ok"] and case["kind"] == "direct":
                roots = {path.split(".")[0] for path in case["focus_fields"]}
                outcome["value"] = {k: v for k, v in outcome["value"].items() if k in roots}
    evidence_cases = [{k: v for k, v in c.items() if k != "expected"} for c in cases]
    report = {"reference": matrix["reference"], "subject_base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
              "environment": {"os": platform.system(), "arch": platform.machine(), "go": subprocess.check_output(["go", "version"], text=True).strip(),
                              "moon": subprocess.check_output(["moon", "version", "--all"], env=ENV, text=True).strip()},
              "scope": "New read-only network configuration fields under existing Field API; no config mutation, complete EthernetInterface parity, approved API translation or physical BMC claim.",
              "summary": dict(Counter(c["relation"] for c in cases)), "cases": evidence_cases, "adapters": observed, "observation_scope": "Full projections asserted by runner; evidence retains focus_fields and their containing objects without normalizing their values or states."}
    paths = ["ethernet_configuration.mbt", "extended_inventory.mbt", "extended_links.mbt", "inventory_fields.mbt", "inventory_links.mbt", "moonredfish.mbt",
             "examples/compare/network_configuration.mbt", "examples/compare/main.mbt", "tools/gofish/network_configuration.go", "tools/gofish/main.go", "tools/gofish/parity.go", "tools/test_network_config.py", "tools/test_gofish.py"]
    report["source_sha256"] = {name: hashlib.sha256((REPO / name).read_bytes()).hexdigest() for name in paths}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"{len(cases)} cases; {report['summary']}; no complete-equivalence row closed")


if __name__ == "__main__":
    main()
