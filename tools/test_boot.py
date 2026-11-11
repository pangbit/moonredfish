#!/usr/bin/env python3
"""Read-only boot options, Secure Boot and signature metadata comparison."""
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

PREFIX=ROOT+"/BootTests"
BOOT_STRINGS=("AutomaticRetryConfig","BootNext","BootOrderPropertySelection","BootSourceOverrideEnabled","BootSourceOverrideMode","BootSourceOverrideTarget","HttpBootUri","StopBootOnFault","TrustedModuleRequiredToBoot","UefiTargetBootSourceOverride")
BOOT_ARRAYS=("AliasBootOrder","BootOrder","BootSourceOverrideTarget@Redfish.AllowableValues","UefiTargetBootSourceOverride@Redfish.AllowableValues")
MODELS={"option":("BootOption",("Alias","BootOptionReference","DisplayName","UefiDevicePath"),("BootOptionEnabled",)),
        "secure":("SecureBoot",("SecureBootCurrentBoot","SecureBootMode"),("SecureBootEnable",)),
        "database":("SecureBootDatabase",("DatabaseId",),()),
        "signature":("Signature",("SignatureString","SignatureType","SignatureTypeRegistry","UefiSignatureOwner"),())}
BOOT_FULL={"AutomaticRetryConfig":"Disabled","BootNext":"Boot0002","BootOrderPropertySelection":"BootOrder","BootSourceOverrideEnabled":"Once",
           "BootSourceOverrideMode":"UEFI","BootSourceOverrideTarget":"Pxe","HttpBootUri":"https://boot.example.invalid/image",
           "StopBootOnFault":"AnyFault","TrustedModuleRequiredToBoot":"Required","UefiTargetBootSourceOverride":"synthetic-device-path",
           "AliasBootOrder":["Pxe","Hdd"],"BootOrder":["Boot0002","Boot0001","Boot0002"],
           "BootSourceOverrideTarget@Redfish.AllowableValues":["Pxe","Hdd","FutureSource"],"UefiTargetBootSourceOverride@Redfish.AllowableValues":[]}
OPTION_FULL={"Alias":"Pxe","BootOptionReference":"Boot0002","DisplayName":"Synthetic network boot","UefiDevicePath":"synthetic-path","BootOptionEnabled":False}
SECURE_FULL={"SecureBootCurrentBoot":"Enabled","SecureBootEnable":False,"SecureBootMode":"UserMode","Actions":{"#SecureBoot.ResetKeys":{"target":ROOT+"/MustNotReset"}}}
DB_FULL={"DatabaseId":"dbx"}
SIG_FULL={"SignatureString":"00112233445566778899aabbccddeeff","SignatureType":"EFI_CERT_SHA256_GUID","SignatureTypeRegistry":"UEFI","UefiSignatureOwner":"00000000-0000-0000-0000-000000000001"}


def field(raw,key,default,client):
    if client=="moonredfish":return MISSING if key not in raw else NULL if raw[key] is None else value(raw[key])
    return (NIL if default is None else value(default)) if raw.get(key) is None else value(raw[key])


def boot_projection(raw,client):
    if raw.get("Boot") is None and client=="moonredfish":return MISSING if "Boot" not in raw else NULL
    body=raw.get("Boot") or {}
    fields={k:field(body,k,None if k=="HttpBootUri" else "",client) for k in BOOT_STRINGS}
    fields.update({k:field(body,k,None,client) for k in BOOT_ARRAYS})
    return value(fields)


def resource_projection(raw,kind,client):
    _,strings,bools=MODELS[kind]
    fields={k:field(raw,k,"",client) for k in strings}
    fields.update({k:field(raw,k,False,client) for k in bools})
    return {"uri":raw["@odata.id"],"id":raw["Id"],"fields":fields}


def make_cases():
    cases=[];routes={ROOT+"/":{"Id":"RootService"}}
    def resource(uri,body):return {"@odata.id":uri,"Id":uri.rsplit("/",1)[-1],**copy.deepcopy(body)}
    def link(uri):return {"@odata.id":uri}
    def add(ident,kind,body,expected=None,gets=None,reject=False):
        uri=PREFIX+"/Cases/"+ident;raw=resource(uri,body);routes[uri]=raw
        if expected is None:expected={c:ok(boot_projection(raw,c) if kind=="boot" else resource_projection(raw,kind,c)) for c in ("moonredfish","gofish")}
        if reject:expected={"moonredfish":error("invalid_response"),"gofish":error("json_type")}
        cases.append({"id":ident,"uri":uri,"kind":kind,"input":raw,"expected":expected,"gets":{c:[uri,*(gets or {}).get(c,[])] for c in ("moonredfish","gofish")}})
    add("boot_full","boot",{"Boot":BOOT_FULL})
    for kind,full in (("option",OPTION_FULL),("secure",SECURE_FULL),("database",DB_FULL),("signature",SIG_FULL)):add(kind+"_full",kind,full)
    add("boot_missing","boot",{})
    add("boot_null","boot",{"Boot":None})
    add("boot_empty","boot",{"Boot":{}})
    add("boot_fields_null","boot",{"Boot":{k:None for k in (*BOOT_STRINGS,*BOOT_ARRAYS)}})
    add("future_boot_values","boot",{"Boot":{**BOOT_FULL,"BootSourceOverrideTarget":"FutureTarget","BootSourceOverrideMode":"FutureMode","AliasBootOrder":["FutureSource"]}})
    add("boot_array_wrong_type","boot",{"Boot":{**BOOT_FULL,"BootOrder":False}},reject=True)
    add("boot_null_array_member","boot",{"Boot":{**BOOT_FULL,"BootOrder":[None]}})
    cases[-1]["expected"]["moonredfish"]=error("invalid_response")
    cases[-1]["expected"]["gofish"]["value"]["value"]["BootOrder"]=value([""])
    add("secure_enable_wrong_type","secure",{**SECURE_FULL,"SecureBootEnable":"false"},reject=True)
    add("database_wrong_type","database",{"DatabaseId":1},reject=True)
    add("signature_wrong_type","signature",{**SIG_FULL,"SignatureString":False},reject=True)
    add("secure_missing_fields","secure",{})
    add("secure_null_fields","secure",{k:None for k in (*MODELS["secure"][1],*MODELS["secure"][2])})
    add("future_signature_type","signature",{**SIG_FULL,"SignatureType":"FutureSignature","SignatureTypeRegistry":"FutureRegistry"})
    option0,option1,secure,db0,db1,sig0,sig1=(PREFIX+"/Objects/"+n for n in ("O0","O1","Secure","DB0","DB1","S0","S1"))
    for uri,body in ((option0,OPTION_FULL),(option1,{**OPTION_FULL,"BootOptionReference":"Boot0001","BootOptionEnabled":True}),
                     (secure,{**SECURE_FULL,"SecureBootCurrentBoot":"Disabled","SecureBootEnable":True,"SecureBootMode":"SetupMode"}),
                     (db0,{"DatabaseId":"db"}),(db1,DB_FULL),(sig0,SIG_FULL),(sig1,{**SIG_FULL,"SignatureString":"ffeeddccbbaa99887766554433221100"})):
        routes[uri]=resource(uri,body)
    def items(uris,kind,c):return value([resource_projection(routes[u],kind,c) for u in uris])
    options,options2=PREFIX+"/Pages/Options",PREFIX+"/Pages/Options?$skip=1"
    routes[options]={"Members":[link(option0)],"Members@odata.nextLink":options2};routes[options2]={"Members":[link(option1)]}
    for kind in ("boot_options","system_boot_options"):
        add(kind+"_paged",kind,{"Boot":{**BOOT_FULL,"BootOptions":link(options)}},
            {c:ok(items([option0,option1],"option",c)) for c in ("moonredfish","gofish")},{c:[options,options2,option0,option1] for c in ("moonredfish","gofish")})
    add("secure_link","secure_boot",{"SecureBoot":link(secure)},
        {c:ok(value(resource_projection(routes[secure],"secure",c))) for c in ("moonredfish","gofish")},{c:[secure] for c in ("moonredfish","gofish")})
    inline=resource(secure,SECURE_FULL)
    add("secure_inline_differs","secure_boot",{"SecureBoot":inline},
        {"moonredfish":ok(value(resource_projection(routes[secure],"secure","moonredfish"))),"gofish":ok(value(resource_projection(inline,"secure","gofish")))},
        {"moonredfish":[secure],"gofish":[]})
    databases=PREFIX+"/Pages/Databases";routes[databases]={"Members":[link(db0),link(db1)]}
    add("database_collection","databases",{**SECURE_FULL,"SecureBootDatabases":link(databases)},
        {c:ok(items([db0,db1],"database",c)) for c in ("moonredfish","gofish")},{c:[databases,db0,db1] for c in ("moonredfish","gofish")})
    signatures,signatures2=PREFIX+"/Pages/Signatures",PREFIX+"/Pages/Signatures?$skip=1"
    routes[signatures]={"Members":[link(sig0)],"Members@odata.nextLink":signatures2};routes[signatures2]={"Members":[link(sig1)]}
    add("signature_collection","signatures",{**DB_FULL,"Signatures":link(signatures)},
        {c:ok(items([sig0,sig1],"signature",c)) for c in ("moonredfish","gofish")},{c:[signatures,signatures2,sig0,sig1] for c in ("moonredfish","gofish")})
    for ident,kind,body,moon in [("secure_absent_link","secure_boot",{},MISSING),("secure_null_link","secure_boot",{"SecureBoot":None},NULL),
                                ("boot_options_absent_link","boot_options",{"Boot":{}},MISSING),("boot_options_null_link","boot_options",{"Boot":{"BootOptions":None}},NULL),
                                ("databases_absent_link","databases",{},MISSING),("signatures_null_link","signatures",{"Signatures":None},NULL)]:
        add(ident,kind,body,{"moonredfish":ok(moon),"gofish":ok(NIL)})
    add("system_options_absent_link","system_boot_options",{"Boot":{}},{"moonredfish":ok(MISSING),"gofish":ok(NIL)},{"moonredfish":[],"gofish":[]})
    denied=PREFIX+"/Denied";routes[denied]=(403,{})
    add("signatures_denied","signatures",{"Signatures":link(denied)},
        {"moonredfish":error("http"),"gofish":error("collection",NIL)},{c:[denied] for c in ("moonredfish","gofish")})
    empty=PREFIX+"/Empty";routes[empty]={"Members":[]}
    add("signatures_empty","signatures",{"Signatures":link(empty)},
        {"moonredfish":ok(value([])),"gofish":ok(NIL)},{c:[empty] for c in ("moonredfish","gofish")})
    # Issues #483/#428: compare parsed raw retention, not a claimed typed annotation API.
    annotated={"Boot":{**BOOT_FULL,"BootNext@Message.ExtendedInfo":[{"MessageId":"Synthetic.1.0.Pending","MessageArgs":["synthetic-only"]}],"Oem":{"Synthetic":{"Unmodeled":True}}},
               "@Message.ExtendedInfo":[{"MessageId":"Synthetic.1.0.General"}]}
    # Issue #516: current Boot stays current; Settings is metadata, not an implicit read/write target.
    pending=PREFIX+"/PendingSettings";routes[pending]=resource(pending,{"Boot":{**BOOT_FULL,"BootNext":"PendingValue"},"@odata.etag":"synthetic-pending-etag"})
    current={"Boot":BOOT_FULL,"@odata.etag":"synthetic-current-etag","@Redfish.Settings":{"SettingsObject":link(pending)}}
    for ident,body in (("issue_property_annotations_raw",annotated),("issue_current_boot_settings",current)):
        raw=resource(PREFIX+"/Cases/"+ident,body)
        add(ident,"boot_metadata",body,{c:ok({"boot":boot_projection(raw,c),"raw":raw,"boot_raw":raw["Boot"]}) for c in ("moonredfish","gofish")})
    routes[PREFIX]={"Cases":[{"ID":c["id"],"URI":c["uri"],"Kind":c["kind"]} for c in cases]}
    return cases,routes


def item_ids(kind):
    if kind in ("boot","boot_metadata"):
        translated={"HttpBootUri":"HTTPBootURI","BootSourceOverrideTarget@Redfish.AllowableValues":"AllowableBootSourceOverrideTargetValues","UefiTargetBootSourceOverride@Redfish.AllowableValues":"AllowableUefiTargetBootSourceOverrideValues"}
        return ["schemas::type::Boot","schemas::method::*Boot.UnmarshalJSON","schemas::field::ComputerSystem.Boot"]+["schemas::field::Boot."+translated.get(k,k) for k in (*BOOT_STRINGS,*BOOT_ARRAYS)]
    if kind in MODELS:
        typ,strings,bools=MODELS[kind]
        result=["schemas::type::"+typ,"schemas::function::Get"+typ]+["schemas::field::"+typ+"."+k.replace("Id","ID") for k in (*strings,*bools)]
        if typ!="Signature":result.append("schemas::method::*"+typ+".UnmarshalJSON")
        return result
    names={"boot_options":"*Boot.BootOptions","system_boot_options":"*ComputerSystem.BootOptions","secure_boot":"*ComputerSystem.SecureBoot","databases":"*SecureBoot.SecureBootDatabases","signatures":"*SecureBootDatabase.Signatures"}
    return ["schemas::method::"+names[kind]]


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--report",type=Path);args=parser.parse_args()
    cases,routes=make_cases();observed={}
    with tempfile.TemporaryDirectory(prefix="moonredfish-boot-") as tmp:
        binary=Path(tmp)/"gofish-compare"
        subprocess.run(["go","build","-mod=readonly","-o",str(binary),"."],cwd=REPO/"tools/gofish",env=ENV,check=True,timeout=180)
        for client,command in {"moonredfish":["moon","run","examples/compare","--target","native","--"],"gofish":[str(binary)]}.items():
            with fixture(routes) as (endpoint,state):
                output=run_adapter(client,command,"boot",endpoint)["cases"];traces=trace_cases(state["requests"],cases)
                assert set(output)=={c["id"] for c in cases}
                for case in cases:
                    ident=case["id"]
                    assert output[ident]==case["expected"][client],f"{client}: {ident}: {output[ident]!r} != {case['expected'][client]!r}"
                    assert Counter(traces[ident])==Counter(case["gets"][client]),f"{client}: {ident} requests differ: {traces[ident]}"
                assert traces["startup"]==([ROOT+"/"] if client=="gofish" else [])+[PREFIX]
                assert not state["unexpected"] and state["login"]==state["logout"]==0
                observed[client]={"observations":output,"request_sequences":traces}
            print(client+": boot configuration/options, current versus next Secure Boot state, databases and signatures checked")
    matrix=json.loads((REPO/"docs/gofish/api-v0.27.0.json").read_text())
    ids={f["package"]+"::"+r["kind"]+"::"+r["name"] for f in matrix["files"] for r in f["symbols"]}
    for case in cases:
        case["item_ids"]=item_ids(case["kind"]);assert set(case["item_ids"])<=ids
        m,g=case["expected"]["moonredfish"],case["expected"]["gofish"]
        case["relation"]="same_selected_observation" if m==g else "both_reject" if not m["ok"] and not g["ok"] and m["value"]==g["value"] else "known_difference"
    paths=("boot_inventory.mbt","boot_links.mbt","inventory_fields.mbt","inventory_links.mbt","moonredfish.mbt","examples/compare/boot.mbt","examples/compare/main.mbt","tools/gofish/boot.go","tools/gofish/main.go","tools/test_boot.py","tools/test_gofish.py","tools/test_parity.py")
    report={"reference":matrix["reference"],"subject_base_commit":subprocess.check_output(["git","rev-parse","HEAD"],cwd=REPO,text=True).strip(),
            "environment":{"os":platform.system(),"arch":platform.machine(),"go":subprocess.check_output(["go","version"],text=True).strip(),"moon":subprocess.check_output(["moon","version","--all"],env=ENV,text=True).strip()},
            "scope":"Selected boot configuration, options, Secure Boot/database/signature reads under existing Field/strict decoder contract. No compatibility mode, numeric migration, key or boot operation, publication or hardware claim.",
            "summary":dict(Counter(c["relation"] for c in cases)),"cases":[{k:v for k,v in c.items() if k!="expected"} for c in cases],"adapters":observed,
            "fixtures_sha256":{u:hashlib.sha256(json.dumps(b).encode()).hexdigest() for u,b in routes.items()},
            "source_sha256":{n:hashlib.sha256((REPO/n).read_bytes()).hexdigest() for n in paths}}
    if args.report:args.report.write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n")
    print(f"{len(cases)} boot cases; {report['summary']}; full parity remains open")


if __name__=="__main__":main()
