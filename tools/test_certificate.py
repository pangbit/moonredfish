#!/usr/bin/env python3
"""Selected certificate metadata and explicit read-only navigation comparison."""
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

PREFIX = ROOT + "/CertificateTests"
CLIENTS = ("moonredfish", "gofish")
CERT_STRINGS = ("CertificateString", "CertificateType", "Fingerprint", "FingerprintHashAlgorithm", "SerialNumber", "SignatureAlgorithm", "UefiSignatureOwner", "ValidNotAfter", "ValidNotBefore")
CERT_ARRAYS = ("CertificateUsageTypes", "KeyUsage")
IDENT_STRINGS = ("City", "CommonName", "Country", "DisplayString", "Email", "Organization", "OrganizationalUnit", "State")
IDENT_ARRAYS = ("AdditionalCommonNames", "AdditionalOrganizationalUnits", "AlternativeNames", "DomainComponents")
HEALTH = {"State": "Enabled", "Health": "OK", "HealthRollup": "Warning"}
IDENTIFIER = {"City": "Synthetic City", "CommonName": "leaf.example.invalid", "Country": "ZZ", "DisplayString": "CN=synthetic",
              "Email": "synthetic@example.invalid", "Organization": "Synthetic Org", "OrganizationalUnit": "Synthetic Unit", "State": "Synthetic Region",
              "AdditionalCommonNames": ["second", "third", "second"], "AdditionalOrganizationalUnits": [],
              "AlternativeNames": ["leaf.example.invalid", "alt.example.invalid"], "DomainComponents": ["example", "invalid"], "Oem": {"Synthetic": True}}
FULL = {"CertificateString": "synthetic-not-a-real-certificate", "CertificateType": "PEM", "Fingerprint": "aA:00:bB", "FingerprintHashAlgorithm": "sha256",
        "SerialNumber": "00Af", "SignatureAlgorithm": "1.2.840.113549.1.1.11", "UefiSignatureOwner": "00000000-0000-0000-0000-000000000001",
        "ValidNotBefore": "2026-11-11T00:00:00Z", "ValidNotAfter": "2027-11-11T00:00:00Z", "CertificateUsageTypes": ["Web", "BIOS", "Web"],
        "KeyUsage": ["DigitalSignature", "ServerAuthentication"], "Issuer": {**IDENTIFIER, "CommonName": "issuer.example.invalid"}, "Subject": IDENTIFIER,
        "Status": HEALTH, "SPDM": {"SlotId": 3}, "Actions": {"#Certificate.Renew": {"target": ROOT + "/MustNotRenew"}}}


def field(raw, key, default, client):
    if client == "moonredfish":
        return MISSING if key not in raw else NULL if raw[key] is None else value(raw[key])
    return (NIL if default is None else value(default)) if raw.get(key) is None else value(raw[key])


def project(raw, client, kind="certificate"):
    if kind == "resource":
        return {"uri": raw["@odata.id"], "id": raw["Id"], "name": raw["Name"]}
    fields = {k: field(raw, k, "", client) for k in CERT_STRINGS}
    fields.update({k: field(raw, k, None, client) for k in CERT_ARRAYS})
    for key, strings, arrays in (("Issuer", IDENT_STRINGS, IDENT_ARRAYS), ("Subject", IDENT_STRINGS, IDENT_ARRAYS), ("Status", tuple(HEALTH), ())):
        if raw.get(key) is None and client == "moonredfish":
            fields[key] = MISSING if key not in raw else NULL
        else:
            obj = raw.get(key) or {}
            fields[key] = value({**{k: field(obj, k, "", client) for k in strings}, **{k: field(obj, k, None, client) for k in arrays}})
    return {"uri": raw["@odata.id"], "id": raw["Id"], "fields": fields}


def make_cases():
    cases, routes = [], {ROOT + "/": {"Id": "RootService"}}
    def resource(uri, body):
        return {"@odata.id": uri, "Id": uri.rsplit("/", 1)[-1], "Name": "Synthetic resource", **copy.deepcopy(body)}
    def link(uri):
        return {"@odata.id": uri}
    def add(ident, kind, body, expected=None, gets=None, reject=False):
        uri = PREFIX + "/Cases/" + ident; raw = resource(uri, body); routes[uri] = raw
        if reject:
            expected = {"moonredfish": error("invalid_response"), "gofish": error("json_type")}
        elif expected is None:
            expected = {c: ok(project(raw, c)) for c in CLIENTS}
        cases.append({"id": ident, "kind": kind, "uri": uri, "input": raw, "expected": expected,
                      "gets": {c: [uri, *(gets or {}).get(c, [])] for c in CLIENTS}})
    add("certificate_full", "certificate", FULL)
    add("certificate_missing", "certificate", {})
    add("certificate_null", "certificate", {k: None for k in (*CERT_STRINGS, *CERT_ARRAYS, "Issuer", "Subject", "Status")})
    add("identifiers_empty", "certificate", {**FULL, "Issuer": {}, "Subject": {}})
    add("future_types", "certificate", {**FULL, "CertificateType": "FutureFormat", "CertificateUsageTypes": ["FutureUsage"], "KeyUsage": ["FutureKeyUsage"]})
    add("issuer_wrong_type", "certificate", {**FULL, "Issuer": []}, reject=True)
    add("key_usage_wrong_type", "certificate", {**FULL, "KeyUsage": "DigitalSignature"}, reject=True)
    add("fingerprint_wrong_type", "certificate", {**FULL, "Fingerprint": 123}, reject=True)
    add("key_usage_null_member", "certificate", {**FULL, "KeyUsage": [None]})
    cases[-1]["expected"]["moonredfish"] = error("invalid_response")
    cases[-1]["expected"]["gofish"]["value"]["fields"]["KeyUsage"] = value([""])
    add("identifier_null_member", "certificate", {**FULL, "Subject": {**IDENTIFIER, "AlternativeNames": [None]}})
    cases[-1]["expected"]["moonredfish"] = error("invalid_response")
    cases[-1]["expected"]["gofish"]["value"]["fields"]["Subject"]["value"]["AlternativeNames"] = value([""])
    add("certificate_empty_string", "certificate", {**FULL, "CertificateString": ""})
    add("unselected_spdm_wrong_type", "certificate", {**FULL, "SPDM": "not-an-object"})
    cases[-1]["expected"]["gofish"] = error("json_type")
    add("validity_unparsed", "certificate", {**FULL, "ValidNotBefore": "future-format", "ValidNotAfter": ""})
    service, locations, c0, c1 = (PREFIX + "/Objects/" + n for n in ("Service", "Locations", "C0", "C1"))
    for uri, body in ((service, {"CertificateLocations": link(locations)}), (locations, {"Links": {"Certificates": [link(c1), link(c0)]}}),
                      (c0, FULL), (c1, {**FULL, "Subject": {**IDENTIFIER, "CommonName": "other.example.invalid"}, "Links": {"Subjects": [link(PREFIX + "/MustNotRecurse")]}})):
        routes[uri] = resource(uri, body)
    def items(uris, client):
        return value([project(routes[u], client) for u in uris])
    add("service_link", "service", {"CertificateService": link(service)}, {c: ok(value(project(routes[service], c, "resource"))) for c in CLIENTS}, {c: [service] for c in CLIENTS})
    add("locations_link", "locations", {"CertificateLocations": link(locations)}, {c: ok(value(project(routes[locations], c, "resource"))) for c in CLIENTS}, {c: [locations] for c in CLIENTS})
    add("located_order", "located", {"Links": {"Certificates": [link(c1), link(c0)]}}, {c: ok(items([c1, c0], c)) for c in CLIENTS}, {c: [c1, c0] for c in CLIENTS})
    page, page2, other = PREFIX + "/Pages/Certificates", PREFIX + "/Pages/Certificates?$skip=1", PREFIX + "/MustNotMixBootAndSystem"
    routes[page] = {"Members": [link(c0)], "Members@odata.nextLink": page2}; routes[page2] = {"Members": [link(c1)]}
    routes[other] = {"Members": []}
    for kind in ("system_certificates", "database_certificates", "boot_certificates"):
        owner = {"Certificates": link(page), "Boot": {"Certificates": link(other)}} if kind != "boot_certificates" else {"Certificates": link(other), "Boot": {"Certificates": link(page)}}
        add(kind + "_paged", kind, owner, {c: ok(items([c0, c1], c)) for c in CLIENTS}, {c: [page, page2, c0, c1] for c in CLIENTS})
    add("subjects_order", "subjects", {**FULL, "Links": {"Subjects": [link(c1), link(c0)]}}, {c: ok(items([c1, c0], c)) for c in CLIENTS}, {c: [c1, c0] for c in CLIENTS})
    for kind, key, uri in (("service", "CertificateService", service), ("locations", "CertificateLocations", locations)):
        inline = {**routes[uri], "Name": "Inline different name"}
        add(kind + "_inline_differs", kind, {key: inline}, {"moonredfish": ok(value(project(routes[uri], "moonredfish", "resource"))), "gofish": ok(value(project(inline, "gofish", "resource")))}, {"moonredfish": [uri], "gofish": []})
    add("located_duplicates", "located", {"Links": {"Certificates": [link(c0), link(c0)]}},
        {"moonredfish": ok(items([c0], "moonredfish")), "gofish": ok(items([c0, c0], "gofish"))}, {"moonredfish": [c0], "gofish": [c0, c0]})
    for ident, kind, body, native in (("service_absent", "service", {}, MISSING), ("locations_null", "locations", {"CertificateLocations": None}, NULL),
                                     ("database_absent", "database_certificates", {}, MISSING), ("boot_null", "boot_certificates", {"Boot": None}, NULL),
                                     ("subjects_empty", "subjects", {**FULL, "Links": {"Subjects": []}}, value([]))):
        add(ident, kind, body, {"moonredfish": ok(native), "gofish": ok(NIL)})
    denied, partial = PREFIX + "/Denied", PREFIX + "/Pages/Partial"
    routes[denied] = (403, {}); routes[partial] = {"Members": [link(c0), link(denied)]}
    add("database_denied_member", "database_certificates", {"Certificates": link(partial)}, {"moonredfish": error("http"), "gofish": error("collection", items([c0], "gofish"))}, {c: [partial, c0, denied] for c in CLIENTS})
    routes["/outside"] = resource("/outside", FULL)
    add("subjects_invalid_later_path", "subjects", {**FULL, "Links": {"Subjects": [link(c0), link("/outside")]}}, {"moonredfish": error("invalid_path"), "gofish": ok(items([c0, "/outside"], "gofish"))}, {"moonredfish": [], "gofish": [c0, "/outside"]})
    routes[PREFIX] = {"Cases": [{"ID": c["id"], "URI": c["uri"], "Kind": c["kind"]} for c in cases]}
    return cases, routes


def item_ids(kind):
    if kind == "certificate":
        return ["schemas::type::Certificate", "schemas::type::CertificateIdentifier", "schemas::method::*Certificate.UnmarshalJSON", "schemas::function::GetCertificate"] + ["schemas::field::Certificate." + k for k in (*CERT_STRINGS, *CERT_ARRAYS, "Issuer", "Subject", "Status")] + ["schemas::field::CertificateIdentifier." + k for k in (*IDENT_STRINGS, *IDENT_ARRAYS)]
    return {"service": [".::method::*Service.CertificateService"], "locations": ["schemas::method::*CertificateService.CertificateLocations"],
            "located": ["schemas::method::*CertificateLocations.Certificates"], "system_certificates": ["schemas::method::*ComputerSystem.Certificates"],
            "database_certificates": ["schemas::method::*SecureBootDatabase.Certificates"], "boot_certificates": ["schemas::method::*Boot.Certificates"], "subjects": ["schemas::method::*Certificate.Subjects"]}[kind]


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--report", type=Path); args = parser.parse_args()
    cases, routes = make_cases(); observed = {}
    with tempfile.TemporaryDirectory(prefix="moonredfish-certificate-") as tmp:
        binary = Path(tmp) / "gofish-compare"
        subprocess.run(["go", "build", "-mod=readonly", "-o", str(binary), "."], cwd=REPO / "tools/gofish", env=ENV, check=True, timeout=180)
        for client, command in {"moonredfish": ["moon", "run", "examples/compare", "--target", "native", "--"], "gofish": [str(binary)]}.items():
            with fixture(routes) as (endpoint, state):
                output = run_adapter(client, command, "certificate", endpoint)["cases"]; traces = trace_cases(state["requests"], cases)
                assert set(output) == {c["id"] for c in cases}
                for case in cases:
                    ident = case["id"]
                    assert output[ident] == case["expected"][client], f"{client}: {ident}: {output[ident]!r} != {case['expected'][client]!r}"
                    assert Counter(traces[ident]) == Counter(case["gets"][client]), f"{client}: {ident} requests differ: {traces[ident]}"
                assert traces["startup"] == ([ROOT + "/"] if client == "gofish" else []) + [PREFIX]
                assert not state["unexpected"] and state["login"] == state["logout"] == 0
                observed[client] = {"observations": output, "request_sequences": traces}
            print(client + ": certificate metadata/identities and explicit links checked without enrollment or trust changes")
    matrix = json.loads((REPO / "docs/gofish/api-v0.27.0.json").read_text())
    ids = {f["package"] + "::" + r["kind"] + "::" + r["name"] for f in matrix["files"] for r in f["symbols"]}
    for case in cases:
        case["item_ids"] = item_ids(case["kind"]); assert set(case["item_ids"]) <= ids
        m, g = case["expected"]["moonredfish"], case["expected"]["gofish"]
        case["relation"] = "same_selected_observation" if m == g else "both_reject" if not m["ok"] and not g["ok"] and m["value"] == g["value"] else "known_difference"
    paths = ("certificate_inventory.mbt", "certificate_links.mbt", "inventory_fields.mbt", "inventory_links.mbt", "moonredfish.mbt",
             "examples/compare/certificate.mbt", "examples/compare/pcie.mbt", "examples/compare/main.mbt", "tools/gofish/certificate.go",
             "examples/compare/boot.mbt", "examples/compare/task.mbt", "tools/gofish/task.go", "tools/gofish/boot.go", "tools/gofish/pcie.go", "tools/gofish/main.go", "tools/test_certificate.py", "tools/test_gofish.py", "tools/test_parity.py")
    report = {"reference": matrix["reference"], "subject_base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
              "environment": {"os": platform.system(), "arch": platform.machine(), "go": subprocess.check_output(["go", "version"], text=True).strip(), "moon": subprocess.check_output(["moon", "version", "--all"], env=ENV, text=True).strip()},
              "scope": "Selected Certificate/CertificateIdentifier reads and six bounded link APIs under the existing Field contract. No cryptographic validation, trust changes, enrollment, renewal, exception decision or physical BMC.",
              "summary": dict(Counter(c["relation"] for c in cases)), "cases": [{k: v for k, v in c.items() if k != "expected"} for c in cases], "adapters": observed,
              "fixtures_sha256": {u: hashlib.sha256(json.dumps(b).encode()).hexdigest() for u, b in routes.items()},
              "source_sha256": {n: hashlib.sha256((REPO / n).read_bytes()).hexdigest() for n in paths}}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"{len(cases)} certificate cases; {report['summary']}; no complete certificate/GoFish equivalence claim")


if __name__ == "__main__":
    main()
