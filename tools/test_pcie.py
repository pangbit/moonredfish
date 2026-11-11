#!/usr/bin/env python3
"""PCIe typed inventory and explicit topology reads, synthetic loopback only."""
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

PREFIX = ROOT + "/PCIeTests"
DEVICE_STRINGS = ("AssetTag", "DeviceType", "FirmwareVersion", "Manufacturer", "Model", "PartNumber", "SKU", "SerialNumber", "SparePartNumber", "StagedVersion", "UUID")
DEVICE_BOOLS = ("LocationIndicatorActive", "ReadyToRemove")
FUNCTION_STRINGS = ("ARIFunctionNumber", "BusNumber", "ClassCode", "DeviceClass", "DeviceId", "DeviceNumber", "FunctionNumber", "FunctionProtocol", "FunctionType", "RevisionId", "SegmentNumber", "SubsystemId", "SubsystemVendorId", "VendorId")
FUNCTION_BOOLS = ("ARIModeEnabled", "Enabled")
HEALTH = {"State": "Enabled", "Health": "OK", "HealthRollup": "OK"}
D_FULL = {**{k: "synthetic-"+k for k in DEVICE_STRINGS}, "DeviceType": "MultiFunction", "LocationIndicatorActive": False, "ReadyToRemove": False,
          "PCIeInterface": {"LanesInUse": 4, "MaxLanes": 16, "MaxPCIeType": "Gen5", "PCIeType": "Gen4"}, "Status": HEALTH}
F_FULL = {**{k: "0x01" for k in FUNCTION_STRINGS}, "DeviceClass": "NetworkController", "FunctionType": "Physical", "FunctionProtocol": "PCIe",
          "VendorId": "1abc", "DeviceId": "1234", "ARIModeEnabled": False, "Enabled": False, "FunctionId": 0, "Status": HEALTH}


def field(raw, key, default, client):
    if client == "moonredfish":
        return MISSING if key not in raw else NULL if raw[key] is None else value(raw[key])
    if raw.get(key) is None:
        return NIL if default is None else value(default)
    return value(raw[key])


def project(raw, kind, client, overrides=None):
    strings, bools = (DEVICE_STRINGS, DEVICE_BOOLS) if kind == "device" else (FUNCTION_STRINGS, FUNCTION_BOOLS)
    fields = {k: field(raw, k, "", client) for k in strings}
    fields.update({k: field(raw, k, False, client) for k in bools})
    for key, defaults in [("Status", {k: "" for k in HEALTH})] + ([("PCIeInterface", {"LanesInUse": None, "MaxLanes": None, "PCIeType": "", "MaxPCIeType": ""})] if kind == "device" else []):
        if raw.get(key) is None and client == "moonredfish":
            fields[key] = MISSING if key not in raw else NULL
        else:
            body = raw.get(key) if isinstance(raw.get(key), dict) else {}
            fields[key] = value({k: field(body, k, default, client) for k, default in defaults.items()})
    if kind == "function":
        fields["FunctionId"] = field(raw, "FunctionId", None, client)
    if overrides:
        for key, override in overrides.items():
            fields["PCIeInterface"]["value"][key] = value(override)
    return {"uri": raw["@odata.id"], "id": raw["Id"], "fields": fields}


def make_cases():
    cases, routes = [], {ROOT + "/": {"Id": "RootService"}}
    def resource(uri, body):
        return {"@odata.id": uri, "Id": uri.rsplit("/", 1)[-1], **copy.deepcopy(body)}
    d0, d1, f0, f1 = (PREFIX+"/Objects/"+name for name in ("D0", "D1", "F0", "F1"))
    for uri, body in ((d0,D_FULL),(d1,D_FULL),(f0,F_FULL),(f1,F_FULL),("/outside",D_FULL)):
        routes[uri] = resource(uri, body)
    denied = PREFIX+"/Denied"
    routes[denied] = (403, {})
    link = lambda uri: {"@odata.id": uri}
    def add(ident, kind, body, results=None, gets=None, focus=None, go_overrides=None, reject=None):
        uri = PREFIX+"/Cases/"+ident
        raw = resource(uri, body)
        routes[uri] = raw
        if results is None:
            results = {c: ok(project(raw, kind, c, go_overrides if c=="gofish" else None)) for c in ("moonredfish","gofish")}
        if reject:
            results["moonredfish"] = error("invalid_response")
            if reject=="both": results["gofish"] = error("json_type")
        cases.append({"id":ident,"uri":uri,"kind":kind,"input":raw,"focus":focus,"expected":results,
                      "gets":{c:[uri,*(gets or {}).get(c,[])] for c in ("moonredfish","gofish")}})
    def items(uris,kind,client):
        return value([project(routes[u],kind,client) for u in uris])
    add("device_full","device",D_FULL)
    add("function_full","function",F_FULL)
    add("device_missing","device",{})
    add("function_null","function",{k:None for k in (*FUNCTION_STRINGS,*FUNCTION_BOOLS,"FunctionId","Status")})
    add("future_generations","device",{**D_FULL,"PCIeInterface":{"LanesInUse":0,"MaxLanes":0,"PCIeType":"FutureGen","MaxPCIeType":"FutureGen"}})
    for ident, lane, observed in [("lane_string","8",8),("lane_invalid_string","not-a-number",0),("lane_bool",True,0),("lane_fraction",1.5,1),("lane_negative",-1,-1),("lane_float32_rounding",16777217,16777216)]:
        add(ident,"device",{**D_FULL,"PCIeInterface":{**D_FULL["PCIeInterface"],"LanesInUse":lane}},
            focus="PCIeInterface",go_overrides={"LanesInUse":observed},reject=None if ident=="lane_float32_rounding" else "moon")
    add("interface_empty_array","device",{**D_FULL,"PCIeInterface":[]},focus="PCIeInterface",reject="moon")
    add("wrong_device_model","device",{**D_FULL,"Model":1},focus="Model",reject="both")
    add("wrong_function_enabled","function",{**F_FULL,"Enabled":"false"},focus="Enabled",reject="both")
    add("function_decimal_id","function",{**F_FULL,"FunctionId":1.0},focus="FunctionId")
    cases[-1]["expected"]["gofish"] = error("json_type")
    # The member URI array and source order are explicit; no inferred PCIe paths.
    add("system_devices","system_devices",{"PCIeDevices":[link(d1),link(d0)]},
        {c:ok(items([d1,d0],"device",c)) for c in ("moonredfish","gofish")},{c:[d1,d0] for c in ("moonredfish","gofish")})
    add("system_functions","system_functions",{"PCIeFunctions":[link(f0)]},
        {c:ok(items([f0],"function",c)) for c in ("moonredfish","gofish")},{c:[f0] for c in ("moonredfish","gofish")})
    page, page2 = PREFIX+"/Pages/Devices",PREFIX+"/Pages/Devices?$skip=1"
    routes[page]={"Members":[link(d0)],"Members@odata.nextLink":page2};routes[page2]={"Members":[link(d1)]}
    add("chassis_paged","chassis_devices",{"PCIeDevices":link(page)},
        {c:ok(items([d0,d1],"device",c)) for c in ("moonredfish","gofish")},{c:[page,page2,d0,d1] for c in ("moonredfish","gofish")})
    add("chassis_legacy","chassis_devices",{"Links":{"PCIeDevices":[link(d0)]}},
        {c:ok(items([d0],"device",c)) for c in ("moonredfish","gofish")},{c:[d0] for c in ("moonredfish","gofish")})
    modern = PREFIX+"/Pages/Priority"
    routes[modern]={"Members":[link(d0)]}
    add("chassis_prefers_collection","chassis_devices",{"PCIeDevices":link(modern),"Links":{"PCIeDevices":[link(d1)]}},
        {c:ok(items([d0],"device",c)) for c in ("moonredfish","gofish")},{c:[modern,d0] for c in ("moonredfish","gofish")})
    funcs=PREFIX+"/Pages/Functions";routes[funcs]={"Members":[link(f1)]}
    for ident, body, selected, paths in [("device_functions_collection",{"PCIeFunctions":link(funcs)},[f1],[funcs,f1]),
        ("device_prefers_legacy",{"PCIeFunctions":link(funcs),"Links":{"PCIeFunctions":[link(f0)]}},[f0],[f0]),
        ("empty_legacy_falls_back",{"PCIeFunctions":link(funcs),"Links":{"PCIeFunctions":[]}},[f1],[funcs,f1])]:
        add(ident,"device_functions",body,{c:ok(items(selected,"function",c)) for c in ("moonredfish","gofish")},{c:paths for c in ("moonredfish","gofish")})
    add("function_parent_device","function_device",{"Links":{"PCIeDevice":link(d0)}},
        {c:ok(value(project(routes[d0],"device",c))) for c in ("moonredfish","gofish")},{c:[d0] for c in ("moonredfish","gofish")})
    for ident,kind,body,moon,go in [("system_missing","system_devices",{},MISSING,NIL),("system_null","system_devices",{"PCIeDevices":None},NULL,NIL),
        ("chassis_missing","chassis_devices",{},MISSING,value([])),("functions_missing","device_functions",{},MISSING,NIL),
        ("parent_null","function_device",{"Links":{"PCIeDevice":None}},NULL,NIL)]:
        add(ident,kind,body,{"moonredfish":ok(moon),"gofish":ok(go)})
    add("duplicate_devices","system_devices",{"PCIeDevices":[link(d0),link(d0)]},
        {"moonredfish":ok(items([d0],"device","moonredfish")),"gofish":ok(items([d0,d0],"device","gofish"))},
        {"moonredfish":[d0],"gofish":[d0,d0]})
    add("invalid_later_path","system_devices",{"PCIeDevices":[link(d0),link("/outside")]},
        {"moonredfish":error("invalid_path"),"gofish":ok(items([d0,"/outside"],"device","gofish"))},
        {"moonredfish":[],"gofish":[d0,"/outside"]})
    add("denied_member","system_devices",{"PCIeDevices":[link(d0),link(denied)]},
        {"moonredfish":error("http"),"gofish":error("collection",items([d0],"device","gofish"))},{c:[d0,denied] for c in ("moonredfish","gofish")})
    routes[PREFIX]={"Cases":[{"ID":c["id"],"URI":c["uri"],"Kind":c["kind"]} for c in cases]}
    return cases,routes


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--report",type=Path);args=parser.parse_args()
    cases,routes=make_cases();observed={}
    with tempfile.TemporaryDirectory(prefix="moonredfish-pcie-") as tmp:
        binary=Path(tmp)/"gofish-compare"
        subprocess.run(["go","build","-mod=readonly","-o",str(binary),"."],cwd=REPO/"tools/gofish",env=ENV,check=True,timeout=180)
        for client,command in {"moonredfish":["moon","run","examples/compare","--target","native","--"],"gofish":[str(binary)]}.items():
            with fixture(routes) as (endpoint,state):
                output=run_adapter(client,command,"pcie",endpoint)["cases"]
                traces=trace_cases(state["requests"],cases)
                assert set(output)=={c["id"] for c in cases}
                for case in cases:
                    ident=case["id"]
                    assert output[ident]==case["expected"][client], f"{client}: {ident}: {output[ident]!r} != {case['expected'][client]!r}"
                    assert Counter(traces[ident])==Counter(case["gets"][client]),f"{client}: {ident} request multiplicity"
                assert traces["startup"]==([ROOT+"/"] if client=="gofish" else [])+[PREFIX]
                assert not state["unexpected"] and state["login"]==state["logout"]==0
                observed[client]={"observations":output,"request_sequences":traces}
            print(client+": PCIe device/function fields, explicit topology and reference source precedence checked")
    matrix=json.loads((REPO/"docs/gofish/api-v0.27.0.json").read_text())
    callable_names={"system_devices":"*ComputerSystem.PCIeDevices","system_functions":"*ComputerSystem.PCIeFunctions","chassis_devices":"*Chassis.PCIeDevices","device_functions":"*PCIeDevice.PCIeFunctions","function_device":"*PCIeFunction.PCIeDevice"}
    for case in cases:
        kind=case["kind"];ids=[]
        if kind in ("device","function"):
            typ="PCIeDevice" if kind=="device" else "PCIeFunction"
            strings,bools=(DEVICE_STRINGS,DEVICE_BOOLS) if kind=="device" else (FUNCTION_STRINGS,FUNCTION_BOOLS)
            names=(*strings,*bools,"PCIeInterface" if kind=="device" else "FunctionId","Status")
            ids=["schemas::field::"+typ+"."+n.replace("Id","ID") for n in names]
            ids += ["schemas::type::"+typ,"schemas::function::Get"+typ,"schemas::method::*"+typ+".UnmarshalJSON"]
            if kind=="device":ids += ["schemas::type::PCIeInterface","schemas::method::*PCIeInterface.UnmarshalJSON"]+["schemas::field::PCIeInterface."+k for k in ("LanesInUse","MaxLanes","MaxPCIeType","PCIeType")]
        else:ids=["schemas::method::"+callable_names[kind]]
        case["item_ids"]=ids
        m,g=case["expected"]["moonredfish"],case["expected"]["gofish"]
        case["relation"]="same_selected_observation" if m==g else "both_reject" if not m["ok"] and not g["ok"] and m["value"]==g["value"] else "known_difference"
    row_ids={f["package"]+"::"+r["kind"]+"::"+r["name"] for f in matrix["files"] for r in f["symbols"]}
    assert {i for c in cases for i in c["item_ids"]} <= row_ids
    evidence=[]
    for case in cases:
        evidence.append({k:v for k,v in case.items() if k!="expected"})
        if case["focus"]:
            for data in observed.values():
                outcome=data["observations"][case["id"]]
                if outcome["ok"]:
                    fields=outcome["value"]["fields"]
                    outcome["value"]["fields"]={case["focus"]:fields[case["focus"]]}
    paths=("pcie_inventory.mbt","pcie_links.mbt","extended_links.mbt","inventory_fields.mbt","inventory_links.mbt","moonredfish.mbt","examples/compare/pcie.mbt","examples/compare/main.mbt","tools/gofish/pcie.go","tools/gofish/main.go","tools/test_pcie.py","tools/test_gofish.py","tools/test_parity.py")
    report={"reference":matrix["reference"],"subject_base_commit":subprocess.check_output(["git","rev-parse","HEAD"],cwd=REPO,text=True).strip(),
            "environment":{"os":platform.system(),"arch":platform.machine(),"go":subprocess.check_output(["go","version"],text=True).strip(),"moon":subprocess.check_output(["moon","version","--all"],env=ENV,text=True).strip()},
            "scope":"Selected PCIe device/function/interface fields and five read entry points. Same observation is not complete API/model parity; no controls or physical BMC.",
            "observation_scope":"Entire adapter projections asserted; focus cases retain only indicated fields in the report. Request sequences retained; concurrent member request multiplicities asserted.",
            "summary":dict(Counter(c["relation"] for c in cases)),"cases":evidence,"adapters":observed,
            "fixtures_sha256":{uri:hashlib.sha256(json.dumps(body).encode()).hexdigest() for uri,body in routes.items()},
            "source_sha256":{name:hashlib.sha256((REPO/name).read_bytes()).hexdigest() for name in paths}}
    if args.report:args.report.write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n")
    print(f"{len(cases)} PCIe cases; {report['summary']}; no full equivalence claim")


if __name__=="__main__":main()
