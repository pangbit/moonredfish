#!/usr/bin/env python3
"""ActionInfo metadata, first-match queries and explicit GET-only annotation navigation."""
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

PREFIX = ROOT + "/ActionInfoTests"
CLIENTS = ("moonredfish", "gofish")
STRINGS = ("Name", "DataType", "DefaultValue", "ObjectDataType", "AllowablePattern")
ARRAYS = ("AllowableNumbers", "AllowableValueDescriptions", "AllowableValues")
BOOLS = ("NoDefaultValue", "Required")
PARAM = {"Name":"Mode", "DataType":"String", "DefaultValue":"{not parsed}", "ObjectDataType":"#Future.v1.Type", "AllowablePattern":"[not compiled",
         "AllowableNumbers":["1:10:2","PT1S:PT5S"], "AllowableValueDescriptions":["second"], "AllowableValues":["B","A","B"], "NoDefaultValue":True, "Required":True,
         "ArraySizeMinimum":0, "ArraySizeMaximum":3, "MinimumValue":-1.5, "MaximumValue":2.5, "Oem":{"Synthetic":True}}
FULL = {"Parameters":[PARAM]}


def field(raw, key, default, client):
    if client == "moonredfish": return MISSING if key not in raw else NULL if raw[key] is None else value(raw[key])
    return (NIL if default is None else value(default)) if raw.get(key) is None else value(raw[key])


def project(raw, client):
    parameters = (MISSING if "Parameters" not in raw else NULL) if client == "moonredfish" else NIL
    if raw.get("Parameters") is not None:
        parameters = value([{**{k:field(p,k,"",client) for k in STRINGS}, **{k:field(p,k,None,client) for k in ARRAYS}, **{k:field(p,k,False,client) for k in BOOLS}} for p in raw["Parameters"]])
    return {"uri":raw["@odata.id"], "id":raw["Id"], "fields":{"Parameters":parameters}}


def make_cases():
    cases,routes=[],{ROOT+"/":{"Id":"RootService"}}
    def resource(uri,body): return {"@odata.id":uri,"Id":uri.rsplit("/",1)[-1],"Name":"Synthetic action metadata",**copy.deepcopy(body)}
    def add(ident,kind,body,expected=None,gets=None,reject=False,name="Mode",typ="String",action=""):
        uri=PREFIX+"/Cases/"+ident;raw=resource(uri,body);routes[uri]=raw
        if reject:expected={"moonredfish":error("invalid_response"),"gofish":error("json_type")}
        elif expected is None:expected={c:ok(project(raw,c)) for c in CLIENTS}
        cases.append({"id":ident,"kind":kind,"uri":uri,"input":raw,"name":name,"type":typ,"action":action,"expected":expected,
                      "gets":{c:[uri,*(gets or {}).get(c,[])] for c in CLIENTS}})
    add("info_full","info",FULL)
    add("parameters_missing","info",{})
    add("parameters_null","info",{"Parameters":None})
    add("parameters_empty","info",{"Parameters":[]})
    add("parameter_empty","info",{"Parameters":[{}]})
    add("parameter_null_fields","info",{"Parameters":[{k:None for k in (*STRINGS,*ARRAYS,*BOOLS)}]})
    add("unknown_type","info",{"Parameters":[{**PARAM,"DataType":"FutureType"}]})
    for ident,body in (("parameters_wrong_type",{"Parameters":{}}),("required_wrong_type",{"Parameters":[{**PARAM,"Required":"true"}]}),("allowable_wrong_type",{"Parameters":[{**PARAM,"AllowableValues":"A"}]})):
        add(ident,"info",body,reject=True)
    add("parameter_null_element","info",{"Parameters":[None]}, {"moonredfish":error("invalid_response"),"gofish":ok(project(resource(PREFIX+"/Cases/parameter_null_element",{"Parameters":[{}]}),"gofish"))})
    add("allowable_null_element","info",{"Parameters":[{**PARAM,"AllowableValues":[None]}]})
    cases[-1]["expected"]["moonredfish"]=error("invalid_response")
    cases[-1]["expected"]["gofish"]["value"]["fields"]["Parameters"]["value"][0]["AllowableValues"]=value([""])
    add("unselected_numeric_wrong_type","info",{"Parameters":[{**PARAM,"MaximumValue":"wrong-type"}]})
    cases[-1]["expected"]["gofish"]=error("json_type")
    def query(ident,parameters,expected,name="Mode",typ="String"):
        add(ident,"query",{"Parameters":parameters},expected,name=name,typ=typ)
    same=lambda x:{c:ok(value(x)) for c in CLIENTS}
    query("query_defined",[PARAM],same(["B","A","B"]))
    query("query_first_match",[{**PARAM,"DataType":"Number","AllowableValues":["skip"]},{**PARAM,"AllowableValues":["first"]},{**PARAM,"AllowableValues":["later"]}],same(["first"]))
    query("query_wildcard_missing",[{"Name":"Mode","AllowableValues":["wildcard"]},PARAM],same(["wildcard"]))
    query("query_wildcard_null",[{**PARAM,"DataType":None}],same(["B","A","B"]))
    query("query_wildcard_empty",[{**PARAM,"DataType":"","AllowableValues":[]},PARAM],same([]))
    query("query_first_values_missing",[{"Name":"Mode"},PARAM],{"moonredfish":ok(MISSING),"gofish":ok(NIL)})
    query("query_first_values_null",[{"Name":"Mode","AllowableValues":None},PARAM],{"moonredfish":ok(NULL),"gofish":ok(NIL)})
    query("query_empty_name",[{"AllowableValues":["unnamed"]}],same(["unnamed"]),name="")
    for ident,parameters,name,typ in (("query_case_sensitive",[PARAM],"mode","String"),("query_type_mismatch",[PARAM],"Mode","Number"),("query_no_parameters",[],"Mode","String")):
        query(ident,parameters,{"moonredfish":error("invalid_response"),"gofish":error("parameter_not_found")},name,typ)
    info=PREFIX+"/Objects/Info";routes[info]=resource(info,FULL)
    for kind,action in (("system_reset","#ComputerSystem.Reset"),("manager_reset","#Manager.Reset"),("insert_info","#VirtualMedia.InsertMedia")):
        add(kind+"_link",kind,{"Actions":{action:{"@Redfish.ActionInfo":info,"target":ROOT+"/MustNotExecute"}}}, {c:ok(value(project(routes[info],c))) for c in CLIENTS},{c:[info] for c in CLIENTS},action=action)
    add("system_info_missing","system_reset",{}, {"moonredfish":ok(MISSING),"gofish":error("unsupported")},action="#ComputerSystem.Reset")
    add("manager_info_null","manager_reset",{"Actions":{"#Manager.Reset":{"@Redfish.ActionInfo":None}}},{"moonredfish":ok(NULL),"gofish":error("unsupported")},action="#Manager.Reset")
    add("insert_info_empty","insert_info",{"Actions":{"#VirtualMedia.InsertMedia":{"@Redfish.ActionInfo":""}}},{"moonredfish":error("invalid_path"),"gofish":error("unsupported")},action="#VirtualMedia.InsertMedia")
    routes["/outside"]=resource("/outside",FULL)
    add("manager_info_unsafe","manager_reset",{"Actions":{"#Manager.Reset":{"@Redfish.ActionInfo":"/outside"}}},{"moonredfish":error("invalid_path"),"gofish":ok(value(project(routes["/outside"],"gofish")))},{"moonredfish":[],"gofish":["/outside"]},action="#Manager.Reset")
    denied=PREFIX+"/Denied";routes[denied]=(403,{})
    add("insert_info_denied","insert_info",{"Actions":{"#VirtualMedia.InsertMedia":{"@Redfish.ActionInfo":denied}}},{c:error("http") for c in CLIENTS},{c:[denied] for c in CLIENTS},action="#VirtualMedia.InsertMedia")
    routes[PREFIX]={"Cases":[{"ID":c["id"],"URI":c["uri"],"Kind":c["kind"],"Name":c["name"],"Type":c["type"],"Action":c["action"]} for c in cases]}
    return cases,routes


def item_ids(kind):
    if kind in ("info","query"):
        return ["schemas::type::ActionInfo","schemas::type::ActionInfoParameter","schemas::field::ActionInfo.Parameters"]+["schemas::field::ActionInfoParameter."+k for k in (*STRINGS,*ARRAYS,*BOOLS)]+(["schemas::method::*ActionInfo.GetParamValues"] if kind=="query" else [])
    return {"system_reset":["schemas::method::*ComputerSystem.ResetActionInfo"],"manager_reset":["schemas::method::*Manager.ResetActionInfo"],"insert_info":["schemas::method::*VirtualMedia.InsertMediaActionInfo"]}[kind]


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--report", type=Path); args = parser.parse_args()
    cases, routes = make_cases(); observed = {}
    with tempfile.TemporaryDirectory(prefix="moonredfish-action-info-") as tmp:
        binary = Path(tmp) / "gofish-compare"
        subprocess.run(["go", "build", "-mod=readonly", "-o", str(binary), "."], cwd=REPO / "tools/gofish", env=ENV, check=True, timeout=180)
        for client, command in {"moonredfish": ["moon", "run", "examples/compare", "--target", "native", "--"], "gofish": [str(binary)]}.items():
            with fixture(routes) as (endpoint, state):
                output = run_adapter(client, command, "action-info", endpoint)["cases"]; traces = trace_cases(state["requests"], cases)
                assert set(output) == {c["id"] for c in cases}
                for case in cases:
                    ident = case["id"]
                    assert output[ident] == case["expected"][client], f"{client}: {ident}: {output[ident]!r} != {case['expected'][client]!r}"
                    assert Counter(traces[ident]) == Counter(case["gets"][client]), f"{client}: {ident} requests differ: {traces[ident]}"
                assert traces["startup"] == ([ROOT + "/"] if client == "gofish" else []) + [PREFIX]
                assert not state["unexpected"] and state["login"] == state["logout"] == 0
                observed[client] = {"observations": output, "request_sequences": traces}
            print(client + ": action metadata, first-match parameter lookup and annotation GETs checked without action execution")
    matrix = json.loads((REPO / "docs/gofish/api-v0.27.0.json").read_text())
    ids = {f["package"] + "::" + r["kind"] + "::" + r["name"] for f in matrix["files"] for r in f["symbols"]}
    for case in cases:
        case["item_ids"] = item_ids(case["kind"]); assert set(case["item_ids"]) <= ids
        m, g = case["expected"]["moonredfish"], case["expected"]["gofish"]
        case["relation"] = "same_selected_observation" if m == g else "both_reject" if not m["ok"] and not g["ok"] and m["value"] == g["value"] else "known_difference"
    paths = ("action_info.mbt", "action_info_links.mbt", "inventory_fields.mbt", "moonredfish.mbt", "examples/compare/action_info.mbt", "examples/compare/main.mbt", "examples/compare/boot.mbt", "examples/compare/parity.mbt", "tools/gofish/action_info.go", "tools/gofish/main.go", "tools/gofish/boot.go", "tools/gofish/parity.go", "tools/test_action_info.py", "tools/test_gofish.py", "tools/test_parity.py")
    report = {"reference": matrix["reference"], "subject_base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
              "environment": {"os": platform.system(), "arch": platform.machine(), "go": subprocess.check_output(["go", "version"], text=True).strip(), "moon": subprocess.check_output(["moon", "version", "--all"], env=ENV, text=True).strip()},
              "scope": "Selected ActionInfo/parameter metadata, first matching name/type query and exact annotation reads compared with three unambiguous GoFish getters. No numeric-contract change, action execution, exception decision or physical BMC.",
              "summary": dict(Counter(c["relation"] for c in cases)), "cases": [{k: v for k, v in c.items() if k != "expected"} for c in cases], "adapters": observed,
              "fixtures_sha256": {u: hashlib.sha256(json.dumps(b).encode()).hexdigest() for u, b in routes.items()},
              "source_sha256": {n: hashlib.sha256((REPO / n).read_bytes()).hexdigest() for n in paths}}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"{len(cases)} action info cases; {report['summary']}; no complete ActionInfo/GoFish equivalence claim")


if __name__ == "__main__":
    main()
