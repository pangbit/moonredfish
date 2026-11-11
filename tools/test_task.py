#!/usr/bin/env python3
"""Read-only task status, messages and explicit navigation differential evidence."""
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

PREFIX = ROOT + "/TaskTests"
CLIENTS = ("moonredfish", "gofish")
TASK_STRINGS = ("EndTime", "EstimatedDuration", "StartTime", "TaskMonitor", "TaskState", "TaskStatus")
MESSAGE_STRINGS = ("Message", "MessageId", "MessageSeverity", "Resolution", "Severity", "UserAuthenticationSource", "Username")
MESSAGE_ARRAYS = ("MessageArgs", "RelatedProperties")
SERVICE_DEFAULTS = {"CompletedTaskOverWritePolicy": "", "DateTime": "", "LifeCycleEventOnTaskStateChange": False,
                    "ServiceEnabled": False, "TaskAutoDeleteTimeoutMinutes": 0, "TaskMonitorAutoExpirySeconds": None}
HEALTH = {"State": "Enabled", "Health": "OK", "HealthRollup": "Warning"}
MESSAGE = {"Message": "Synthetic task report", "MessageId": "Synthetic.1.0.Task", "MessageSeverity": "Critical",
           "Resolution": "Synthetic recommendation only", "Severity": "Warning", "UserAuthenticationSource": "https://auth.example.invalid",
           "Username": "synthetic-user", "MessageArgs": ["first", "second", "first"], "RelatedProperties": ["/Boot/BootNext"],
           "ResolutionSteps": [{"ActionURI": ROOT + "/MustNotAct", "ResolutionType": "Reset"}], "Oem": {"Synthetic": True}}
TASK = {"EndTime": "2026-11-11T01:00:01Z", "EstimatedDuration": "PT1S", "StartTime": "2026-11-11T01:00:00Z",
        "TaskMonitor": ROOT + "/MustNotMonitor", "TaskState": "Completed", "TaskStatus": "OK", "HidePayload": True,
        "PercentComplete": 100, "Messages": [MESSAGE],
        "Payload": {"HttpOperation": "POST", "TargetUri": ROOT + "/MustNotReplay", "HttpHeaders": ["X-Synthetic: never-send"], "JsonBody": "{}"}}
SERVICE = {"CompletedTaskOverWritePolicy": "Oldest", "DateTime": "2026-11-11T01:00:00Z", "LifeCycleEventOnTaskStateChange": True,
           "ServiceEnabled": False, "TaskAutoDeleteTimeoutMinutes": 0, "TaskMonitorAutoExpirySeconds": 60, "Status": HEALTH,
           "Actions": {"#TaskService.DeleteAllCompletedTasks": {"target": ROOT + "/MustNotDelete"}}}


def field(raw, key, default, client):
    if client == "moonredfish":
        return MISSING if key not in raw else NULL if raw[key] is None else value(raw[key])
    return (NIL if default is None else value(default)) if raw.get(key) is None else value(raw[key])


def message(raw, client):
    raw = raw or {}
    result = {k: field(raw, k, "", client) for k in MESSAGE_STRINGS}
    result.update({k: field(raw, k, None, client) for k in MESSAGE_ARRAYS})
    return result


def project(raw, kind, client):
    if kind == "entity":
        return {"uri": raw["@odata.id"], "id": raw["Id"], "name": raw["Name"]}
    if kind == "service":
        fields = {k: field(raw, k, default, client) for k, default in SERVICE_DEFAULTS.items()}
        if raw.get("Status") is None and client == "moonredfish":
            fields["Status"] = MISSING if "Status" not in raw else NULL
        else:
            fields["Status"] = value({k: field(raw.get("Status") or {}, k, "", client) for k in HEALTH})
    else:
        fields = {k: field(raw, k, "", client) for k in TASK_STRINGS}
        fields.update(HidePayload=field(raw, "HidePayload", False, client), PercentComplete=field(raw, "PercentComplete", None, client))
        fields["Messages"] = field(raw, "Messages", None, client) if raw.get("Messages") is None else value([message(m, client) for m in raw["Messages"]])
    return {"uri": raw["@odata.id"], "id": raw["Id"], "fields": fields}


def make_cases():
    cases, routes = [], {ROOT + "/": {"Id": "RootService"}}
    def resource(uri, body):
        return {"@odata.id": uri, "Id": uri.rsplit("/", 1)[-1], "Name": "Synthetic resource", **copy.deepcopy(body)}
    def link(uri):
        return {"@odata.id": uri}
    def add(ident, kind, body, expected=None, gets=None, reject=False):
        uri = PREFIX + "/Cases/" + ident
        raw = resource(uri, body)
        routes[uri] = raw
        if expected is None:
            expected = {c: ok(project(raw, kind, c)) for c in CLIENTS}
        if reject:
            expected = {"moonredfish": error("invalid_response"), "gofish": error("json_type")}
        cases.append({"id": ident, "kind": kind, "uri": uri, "input": raw, "expected": expected,
                      "gets": {c: [uri, *(gets or {}).get(c, [])] for c in CLIENTS}})
    add("task_full", "task", TASK)
    add("service_full", "service", SERVICE)
    for kind, keys in (("task", (*TASK_STRINGS, "HidePayload", "PercentComplete", "Messages")), ("service", (*SERVICE_DEFAULTS, "Status"))):
        add(kind + "_missing", kind, {})
        add(kind + "_null", kind, {k: None for k in keys})
    add("messages_empty", "task", {**TASK, "Messages": []})
    add("messages_null", "task", {**TASK, "Messages": None})
    add("message_empty", "task", {**TASK, "Messages": [{}]})
    add("message_null_member", "task", {**TASK, "Messages": [None]})
    cases[-1]["expected"]["moonredfish"] = error("invalid_response")
    add("message_args_null_member", "task", {**TASK, "Messages": [{**MESSAGE, "MessageArgs": [None]}]})
    cases[-1]["expected"]["moonredfish"] = error("invalid_response")
    cases[-1]["expected"]["gofish"]["value"]["fields"]["Messages"]["value"][0]["MessageArgs"] = value([""])
    add("future_state_and_severity", "task", {**TASK, "TaskState": "FutureState", "TaskStatus": "FutureHealth", "Messages": [{**MESSAGE, "MessageSeverity": "FutureSeverity"}]})
    body = copy.deepcopy(TASK); del body["TaskStatus"]
    add("status_not_inferred_from_messages", "task", body)
    for ident, percent in (("percent_string", "10"), ("percent_negative", -1), ("percent_fraction", 1.5)):
        add(ident, "task", {**TASK, "PercentComplete": percent}, reject=True)
    add("percent_decimal_integer", "task", {**TASK, "PercentComplete": 1.0})
    cases[-1]["expected"]["gofish"] = error("json_type")
    add("percent_above_native_range", "task", {**TASK, "PercentComplete": 2147483648})
    cases[-1]["expected"]["moonredfish"] = error("invalid_response")
    add("percent_above_schema_range", "task", {**TASK, "PercentComplete": 101})
    add("unselected_payload_wrong_type", "task", {**TASK, "Payload": "not-an-object"})
    cases[-1]["expected"]["gofish"] = error("json_type")
    add("service_wrong_boolean", "service", {**SERVICE, "ServiceEnabled": "false"}, reject=True)
    service, t0, t1, e0, e1 = (PREFIX + "/Objects/" + name for name in ("Service", "T0", "T1", "E0", "E1"))
    for uri, body in ((service, SERVICE), (t0, TASK), (t1, {**TASK, "TaskState": "Running", "PercentComplete": 10, "SubTasks": link(PREFIX + "/MustNotRecurse")}), (e0, {}), (e1, {})):
        routes[uri] = resource(uri, body)
    def items(uris, kind, c):
        return value([project(routes[u], kind, c) for u in uris])
    add("root_task_service", "task_service", {"Tasks": link(service)},
        {c: ok(value(project(routes[service], "service", c))) for c in CLIENTS}, {c: [service] for c in CLIENTS})
    inline = resource(service, {**SERVICE, "ServiceEnabled": True})
    add("inline_task_service_differs", "task_service", {"Tasks": inline},
        {"moonredfish": ok(value(project(routes[service], "service", "moonredfish"))), "gofish": ok(value(project(inline, "service", "gofish")))},
        {"moonredfish": [service], "gofish": []})
    page, page2 = PREFIX + "/Pages/Tasks", PREFIX + "/Pages/Tasks?$skip=1"
    routes[page] = {"Members": [link(t1)], "Members@odata.nextLink": page2}; routes[page2] = {"Members": [link(t0)]}
    for kind, key, owner in (("tasks", "Tasks", SERVICE), ("sub_tasks", "SubTasks", TASK)):
        add(kind + "_paged", kind, {**owner, key: link(page)}, {c: ok(items([t1, t0], "task", c)) for c in CLIENTS}, {c: [page, page2, t1, t0] for c in CLIENTS})
    add("created_resources_order", "created", {**TASK, "Links": {"CreatedResources": [link(e1), link(e0)]}},
        {c: ok(items([e1, e0], "entity", c)) for c in CLIENTS}, {c: [e1, e0] for c in CLIENTS})
    add("created_duplicates", "created", {**TASK, "Links": {"CreatedResources": [link(e0), link(e0)]}},
        {"moonredfish": ok(items([e0], "entity", "moonredfish")), "gofish": ok(items([e0, e0], "entity", "gofish"))},
        {"moonredfish": [e0], "gofish": [e0, e0]})
    for ident, kind, body, native in (("service_absent_link", "task_service", {}, MISSING), ("service_null_link", "task_service", {"Tasks": None}, NULL),
                                     ("tasks_absent_link", "tasks", SERVICE, MISSING), ("sub_tasks_null_link", "sub_tasks", {**TASK, "SubTasks": None}, NULL),
                                     ("created_null_links", "created", {**TASK, "Links": None}, NULL), ("created_empty", "created", {**TASK, "Links": {"CreatedResources": []}}, value([]))):
        add(ident, kind, body, {"moonredfish": ok(native), "gofish": ok(NIL)})
    denied, partial = PREFIX + "/Denied", PREFIX + "/Pages/Partial"
    routes[denied] = (403, {}); routes[partial] = {"Members": [link(t0), link(denied)]}
    add("tasks_denied_member", "tasks", {**SERVICE, "Tasks": link(partial)},
        {"moonredfish": error("http"), "gofish": error("collection", items([t0], "task", "gofish"))}, {c: [partial, t0, denied] for c in CLIENTS})
    routes["/outside"] = resource("/outside", {})
    add("created_invalid_later_path", "created", {**TASK, "Links": {"CreatedResources": [link(e0), link("/outside")]}},
        {"moonredfish": error("invalid_path"), "gofish": ok(items([e0, "/outside"], "entity", "gofish"))}, {"moonredfish": [], "gofish": [e0, "/outside"]})
    routes[PREFIX] = {"Cases": [{"ID": c["id"], "URI": c["uri"], "Kind": c["kind"]} for c in cases]}
    return cases, routes


def item_ids(kind):
    if kind in ("task", "service"):
        typ = "Task" if kind == "task" else "TaskService"
        fields = (*TASK_STRINGS, "HidePayload", "PercentComplete", "Messages") if kind == "task" else (*SERVICE_DEFAULTS, "Status")
        result = ["schemas::type::" + typ, "schemas::method::*" + typ + ".UnmarshalJSON", "schemas::function::Get" + typ]
        result += ["schemas::field::" + typ + "." + k for k in fields]
        if kind == "task":
            result += ["schemas::type::Message"] + ["schemas::field::Message." + ("MessageID" if k == "MessageId" else k) for k in (*MESSAGE_STRINGS, *MESSAGE_ARRAYS)]
        return result
    return {"task_service": [".::method::*Service.Tasks"], "tasks": ["schemas::method::*TaskService.Tasks"],
            "sub_tasks": ["schemas::method::*Task.SubTasks"], "created": ["schemas::method::*Task.CreatedResources"]}[kind]


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--report", type=Path); args = parser.parse_args()
    cases, routes = make_cases(); observed = {}
    with tempfile.TemporaryDirectory(prefix="moonredfish-task-") as tmp:
        binary = Path(tmp) / "gofish-compare"
        subprocess.run(["go", "build", "-mod=readonly", "-o", str(binary), "."], cwd=REPO / "tools/gofish", env=ENV, check=True, timeout=180)
        for client, command in {"moonredfish": ["moon", "run", "examples/compare", "--target", "native", "--"], "gofish": [str(binary)]}.items():
            with fixture(routes) as (endpoint, state):
                output = run_adapter(client, command, "task", endpoint)["cases"]; traces = trace_cases(state["requests"], cases)
                assert set(output) == {c["id"] for c in cases}
                for case in cases:
                    ident = case["id"]
                    assert output[ident] == case["expected"][client], f"{client}: {ident}: {output[ident]!r} != {case['expected'][client]!r}"
                    assert Counter(traces[ident]) == Counter(case["gets"][client]), f"{client}: {ident} requests differ: {traces[ident]}"
                assert traces["startup"] == ([ROOT + "/"] if client == "gofish" else []) + [PREFIX]
                assert not state["unexpected"] and state["login"] == state["logout"] == 0
                observed[client] = {"observations": output, "request_sequences": traces}
            print(client + ": task status/progress/messages and explicit links checked without polling or controls")
    matrix = json.loads((REPO / "docs/gofish/api-v0.27.0.json").read_text())
    ids = {f["package"] + "::" + r["kind"] + "::" + r["name"] for f in matrix["files"] for r in f["symbols"]}
    for case in cases:
        case["item_ids"] = item_ids(case["kind"]); assert set(case["item_ids"]) <= ids
        m, g = case["expected"]["moonredfish"], case["expected"]["gofish"]
        case["relation"] = "same_selected_observation" if m == g else "both_reject" if not m["ok"] and not g["ok"] and m["value"] == g["value"] else "known_difference"
    paths = ("task_inventory.mbt", "task_links.mbt", "inventory_fields.mbt", "inventory_links.mbt", "moonredfish.mbt",
             "examples/compare/task.mbt", "examples/compare/pcie.mbt", "examples/compare/main.mbt", "tools/gofish/task.go",
             "tools/gofish/boot.go", "tools/gofish/pcie.go", "tools/gofish/main.go", "tools/test_task.py", "tools/test_gofish.py", "tools/test_parity.py")
    report = {"reference": matrix["reference"], "subject_base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
              "environment": {"os": platform.system(), "arch": platform.machine(), "go": subprocess.check_output(["go", "version"], text=True).strip(), "moon": subprocess.check_output(["moon", "version", "--all"], env=ENV, text=True).strip()},
              "scope": "Selected TaskService/Task/Message reads and four bounded link APIs under existing Field/strict integer contracts. No compatibility decision, TaskMonitor polling, task start/cancel, resolution action, payload replay or physical BMC.",
              "summary": dict(Counter(c["relation"] for c in cases)), "cases": [{k: v for k, v in c.items() if k != "expected"} for c in cases], "adapters": observed,
              "fixtures_sha256": {u: hashlib.sha256(json.dumps(b).encode()).hexdigest() for u, b in routes.items()},
              "source_sha256": {n: hashlib.sha256((REPO / n).read_bytes()).hexdigest() for n in paths}}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"{len(cases)} task cases; {report['summary']}; no complete task/GoFish equivalence claim")


if __name__ == "__main__":
    main()
