#!/usr/bin/env python3
"""Selected virtual-media reads; no media access, mounting, ejection or trust changes."""
import argparse
from collections import Counter
import copy
import hashlib
import json
import platform
import subprocess
import tempfile
from pathlib import Path

from test_gofish import ENV, REPO, ROOT, fixture, run_adapter
from test_parity import MISSING, NULL, NIL, error, ok, value, trace_cases
from test_certificate import FULL as CERTIFICATE, project as certificate_project

PREFIX = ROOT + "/VirtualMediaTests"
CLIENTS = ("moonredfish", "gofish")
STRINGS = ("ConnectedVia", "EjectPolicy", "EjectTimeout", "Image", "ImageName", "MediaType", "TransferMethod", "TransferProtocolType", "UserName")
BOOLS = ("Inserted", "VerifyCertificate", "WriteProtected")
HEALTH = {"State": "Enabled", "Health": "OK", "HealthRollup": "Warning"}
FULL = {"ConnectedVia": "NotConnected", "EjectPolicy": "Timed", "EjectTimeout": "PT60S", "Image": "https://media.example.invalid/synthetic.iso",
        "ImageName": "synthetic.iso", "MediaType": "CD", "MediaTypes": ["CD", "DVD", "CD"], "TransferMethod": "Stream", "TransferProtocolType": "HTTPS",
        "UserName": "synthetic-user", "Inserted": True, "VerifyCertificate": False, "WriteProtected": True, "Status": HEALTH,
        "Actions": {"#VirtualMedia.InsertMedia": {"target": ROOT + "/MustNotInsert", "@Redfish.ActionInfo": ROOT + "/MustNotFetchInsertInfo"},
                    "#VirtualMedia.EjectMedia": {"target": ROOT + "/MustNotEject", "@Redfish.ActionInfo": ROOT + "/MustNotFetchEjectInfo"}}}


def field(raw, key, default, client):
    if client == "moonredfish":
        return MISSING if key not in raw else NULL if raw[key] is None else value(raw[key])
    return (NIL if default is None else value(default)) if raw.get(key) is None else value(raw[key])


def project(raw, client):
    fields = {k: field(raw, k, "", client) for k in STRINGS}
    fields.update({k: field(raw, k, False if k == "VerifyCertificate" else None, client) for k in BOOLS})
    fields["MediaTypes"] = field(raw, "MediaTypes", None, client)
    fields["Status"] = (MISSING if "Status" not in raw else NULL) if raw.get("Status") is None and client == "moonredfish" else value({k: field(raw.get("Status") or {}, k, "", client) for k in HEALTH})
    for kind in ("Insert", "Eject"):
        action = (raw.get("Actions") or {}).get("#VirtualMedia." + kind + "Media") or {}
        fields["SupportsMedia" + kind] = bool(action.get("target"))
    return {"uri": raw["@odata.id"], "id": raw["Id"], "fields": fields}


def make_cases():
    cases, routes = [], {ROOT + "/": {"Id": "RootService"}}
    def resource(uri, body):
        return {"@odata.id": uri, "Id": uri.rsplit("/", 1)[-1], "Name": "Synthetic resource", **copy.deepcopy(body)}
    def link(uri):
        return {"@odata.id": uri}
    def add(ident, kind, body, expected=None, gets=None, reject=False):
        uri = PREFIX + "/Cases/" + ident; raw = resource(uri, body); routes[uri] = raw
        if reject: expected = {"moonredfish": error("invalid_response"), "gofish": error("json_type")}
        elif expected is None: expected = {c: ok(project(raw, c)) for c in CLIENTS}
        cases.append({"id": ident, "kind": kind, "uri": uri, "input": raw, "expected": expected,
                      "gets": {c: [uri, *(gets or {}).get(c, [])] for c in CLIENTS}})
    add("media_full", "media", FULL)
    add("media_missing", "media", {})
    add("media_null", "media", {k: None for k in (*STRINGS, *BOOLS, "MediaTypes", "Status", "Actions")})
    add("explicit_false", "media", {**FULL, **{k: False for k in BOOLS}})
    add("unknown_strings", "media", {**FULL, "ConnectedVia": "FutureConnection", "TransferProtocolType": "FutureProtocol", "EjectPolicy": "FuturePolicy", "EjectTimeout": "future-duration"})
    add("media_type_independent", "media", {**FULL, "MediaType": "FutureSelected", "MediaTypes": []})
    add("image_relative", "media", {**FULL, "Image": ROOT + "/UpdateService/FirmwareInventory/MustNotFetchImage"})
    add("image_null", "media", {**FULL, "Image": None})
    add("action_info_only", "media", {**FULL, "Actions": {"#VirtualMedia.EjectMedia": {"@Redfish.ActionInfo": ROOT + "/MustNotFetchEjectInfo"}}, "SupportsMediaInsert": True, "SupportsMediaEject": True})
    add("action_targets_empty_null", "media", {**FULL, "Actions": {"#VirtualMedia.EjectMedia": {"target": ""}, "#VirtualMedia.InsertMedia": {"target": None}}})
    add("action_null_and_present", "media", {**FULL, "Actions": {"#VirtualMedia.EjectMedia": None, "#VirtualMedia.InsertMedia": {"target": "/outside-read-scope-metadata-only"}}})
    for ident, body in (("inserted_wrong_type", {"Inserted": 0}), ("verify_wrong_type", {"VerifyCertificate": "false"}),
                        ("media_types_wrong_type", {"MediaTypes": "CD"}), ("action_target_wrong_type", {"Actions": {"#VirtualMedia.InsertMedia": {"target": True}}}),
                        ("actions_wrong_type", {"Actions": []})):
        add(ident, "media", {**FULL, **body}, reject=True)
    add("media_types_null_member", "media", {**FULL, "MediaTypes": [None]})
    cases[-1]["expected"]["moonredfish"] = error("invalid_response")
    cases[-1]["expected"]["gofish"]["value"]["fields"]["MediaTypes"] = value([""])
    for ident, body in (("unselected_password_wrong_type", {"Password": 123}),
                        ("unselected_action_info_wrong_type", {"Actions": {"#VirtualMedia.InsertMedia": {"target": ROOT + "/MustNotInsert", "@Redfish.ActionInfo": 123}}})):
        add(ident, "media", {**FULL, **body}); cases[-1]["expected"]["gofish"] = error("json_type")
    m0, m1, c0, c1 = (PREFIX + "/Objects/" + n for n in ("M0", "M1", "ServerCertificate", "ClientCertificate"))
    for uri, body in ((m0,FULL),(m1,{**FULL,"MediaType":"DVD","Inserted":False}),(c0,CERTIFICATE),(c1,{**CERTIFICATE,"Fingerprint":"bb:11"})):
        routes[uri] = resource(uri,body)
    def items(uris, client, cert=False):
        return value([(certificate_project if cert else project)(routes[u],client) for u in uris])
    page, page2 = PREFIX + "/Pages/Media", PREFIX + "/Pages/Media?$skip=1"
    routes[page] = {"Members":[link(m1)], "Members@odata.nextLink":page2}; routes[page2] = {"Members":[link(m0)]}
    for kind in ("system_media","manager_media"):
        add(kind+"_paged",kind,{"VirtualMedia":link(page)}, {c:ok(items([m1,m0],c)) for c in CLIENTS}, {c:[page,page2,m1,m0] for c in CLIENTS})
    for ident,kind,body,native in (("system_absent","system_media",{},MISSING),("manager_null","manager_media",{"VirtualMedia":None},NULL),("client_certificates_absent","client_certificates",FULL,MISSING)):
        add(ident,kind,body,{"moonredfish":ok(native),"gofish":ok(NIL)})
    empty = PREFIX + "/Pages/Empty"; routes[empty] = {"Members":[]}
    add("manager_empty","manager_media",{"VirtualMedia":link(empty)}, {"moonredfish":ok(value([])),"gofish":ok(NIL)}, {c:[empty] for c in CLIENTS})
    cp, sp = PREFIX+"/Pages/ClientCertificates", PREFIX+"/Pages/ServerCertificates"
    routes[cp] = {"Members":[link(c1)]}; routes[sp] = {"Members":[link(c0)]}
    for kind, page, cert in (("client_certificates",cp,c1),("server_certificates",sp,c0)):
        add(kind+"_separate",kind,{**FULL,"ClientCertificates":link(cp),"Certificates":link(sp)}, {c:ok(items([cert],c,True)) for c in CLIENTS}, {c:[page,cert] for c in CLIENTS})
    duplicate, partial, denied = PREFIX+"/Pages/Duplicate", PREFIX+"/Pages/Partial", PREFIX+"/Denied"
    routes[duplicate] = {"Members":[link(m0),link(m0)]}
    add("media_duplicates","system_media",{"VirtualMedia":link(duplicate)}, {"moonredfish":ok(items([m0],"moonredfish")),"gofish":ok(items([m0,m0],"gofish"))}, {"moonredfish":[duplicate,m0],"gofish":[duplicate,m0,m0]})
    routes[denied]=(403,{}); routes[partial]={"Members":[link(m0),link(denied)]}
    add("media_partial_failure","manager_media",{"VirtualMedia":link(partial)}, {"moonredfish":error("http"),"gofish":error("collection",items([m0],"gofish"))}, {c:[partial,m0,denied] for c in CLIENTS})
    routes["/outside"]={"Members":[link(c1)]}
    add("unsafe_client_collection","client_certificates",{**FULL,"ClientCertificates":link("/outside")}, {"moonredfish":error("invalid_path"),"gofish":ok(items([c1],"gofish",True))}, {"moonredfish":[],"gofish":["/outside",c1]})
    routes[PREFIX] = {"Cases":[{"ID":c["id"],"URI":c["uri"],"Kind":c["kind"]} for c in cases]}
    return cases,routes


def item_ids(kind):
    if kind == "media":
        return ["schemas::type::VirtualMedia", "schemas::method::*VirtualMedia.UnmarshalJSON", "schemas::function::GetVirtualMedia"] + ["schemas::field::VirtualMedia." + k for k in (*STRINGS, *BOOLS, "MediaTypes", "Status", "SupportsMediaEject", "SupportsMediaInsert")]
    return {"system_media":["schemas::method::*ComputerSystem.VirtualMedia"], "manager_media":["schemas::method::*Manager.VirtualMedia"],
            "server_certificates":["schemas::method::*VirtualMedia.Certificates"], "client_certificates":["schemas::method::*VirtualMedia.ClientCertificates"]}[kind]


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--report", type=Path); args = parser.parse_args()
    cases, routes = make_cases(); observed = {}
    with tempfile.TemporaryDirectory(prefix="moonredfish-virtual-media-") as tmp:
        binary = Path(tmp) / "gofish-compare"
        subprocess.run(["go", "build", "-mod=readonly", "-o", str(binary), "."], cwd=REPO / "tools/gofish", env=ENV, check=True, timeout=180)
        for client, command in {"moonredfish": ["moon", "run", "examples/compare", "--target", "native", "--"], "gofish": [str(binary)]}.items():
            with fixture(routes) as (endpoint, state):
                output = run_adapter(client, command, "virtual-media", endpoint)["cases"]; traces = trace_cases(state["requests"], cases)
                assert set(output) == {c["id"] for c in cases}
                for case in cases:
                    ident = case["id"]
                    assert output[ident] == case["expected"][client], f"{client}: {ident}: {output[ident]!r} != {case['expected'][client]!r}"
                    assert Counter(traces[ident]) == Counter(case["gets"][client]), f"{client}: {ident} requests differ: {traces[ident]}"
                assert traces["startup"] == ([ROOT + "/"] if client == "gofish" else []) + [PREFIX]
                assert not state["unexpected"] and state["login"] == state["logout"] == 0
                observed[client] = {"observations": output, "request_sequences": traces}
            print(client + ": virtual media states and explicit links checked without image access or controls")
    matrix = json.loads((REPO / "docs/gofish/api-v0.27.0.json").read_text())
    ids = {f["package"] + "::" + r["kind"] + "::" + r["name"] for f in matrix["files"] for r in f["symbols"]}
    for case in cases:
        case["item_ids"] = item_ids(case["kind"]); assert set(case["item_ids"]) <= ids
        m, g = case["expected"]["moonredfish"], case["expected"]["gofish"]
        case["relation"] = "same_selected_observation" if m == g else "both_reject" if not m["ok"] and not g["ok"] and m["value"] == g["value"] else "known_difference"
    paths = ("virtual_media_inventory.mbt", "virtual_media_links.mbt", "tools/test_virtual_media.py", "tools/gofish/virtual_media.go", "examples/compare/virtual_media.mbt", "certificate_inventory.mbt", "certificate_links.mbt", "inventory_fields.mbt", "inventory_links.mbt", "moonredfish.mbt",
             "examples/compare/certificate.mbt", "examples/compare/pcie.mbt", "examples/compare/main.mbt", "tools/gofish/certificate.go",
             "examples/compare/boot.mbt", "examples/compare/task.mbt", "tools/gofish/task.go", "tools/gofish/boot.go", "tools/gofish/pcie.go", "tools/gofish/main.go", "tools/test_certificate.py", "tools/test_gofish.py", "tools/test_parity.py")
    report = {"reference": matrix["reference"], "subject_base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
              "environment": {"os": platform.system(), "arch": platform.machine(), "go": subprocess.check_output(["go", "version"], text=True).strip(), "moon": subprocess.check_output(["moon", "version", "--all"], env=ENV, text=True).strip()},
              "scope": "Selected VirtualMedia metadata, derived advertisement flags and explicit media/certificate collections under the existing Field contract. No image access, insert/eject, credential changes, exception decision or physical BMC.",
              "summary": dict(Counter(c["relation"] for c in cases)), "cases": [{k: v for k, v in c.items() if k != "expected"} for c in cases], "adapters": observed,
              "fixtures_sha256": {u: hashlib.sha256(json.dumps(b).encode()).hexdigest() for u, b in routes.items()},
              "source_sha256": {n: hashlib.sha256((REPO / n).read_bytes()).hexdigest() for n in paths}}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"{len(cases)} virtual media cases; {report['summary']}; no complete virtual-media/GoFish equivalence claim")


if __name__ == "__main__":
    main()
