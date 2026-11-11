///|
test "task preserves contradictory reported state messages and raw payload without inference" {
  let message : Json = {
    "MessageId": "Synthetic.1.0.Task",
    "MessageSeverity": "Critical",
    "Severity": "Warning",
    "MessageArgs": ["second", "first", "second"],
    "RelatedProperties": ["/Boot/BootNext"],
    "ResolutionSteps": [{ "ActionURI": "/redfish/v1/MustNotAct" }],
    "Oem": { "Synthetic": true },
  }
  let raw : Json = {
    "TaskState": "Completed",
    "TaskStatus": "OK",
    "PercentComplete": 101,
    "HidePayload": true,
    "Payload": {
      "HttpOperation": "POST",
      "TargetUri": "/redfish/v1/MustNotReplay",
    },
    "TaskMonitor": "/redfish/v1/MustNotMonitor",
    "Messages": [message],
  }
  let task = @moonredfish.parse_resource(
    "/redfish/v1/TaskService/Tasks/demo", raw,
  ).task()
  assert_eq(task.resource.json, raw)
  assert_eq(task.task_state.value(), Some("Completed"))
  assert_eq(task.task_status.value(), Some("OK"))
  assert_eq(task.percent_complete.value(), Some(101))
  assert_eq(task.hide_payload.value(), Some(true))
  let messages = task.messages.value().unwrap()
  assert_eq(messages[0].json, message)
  assert_eq(messages[0].message_severity.value(), Some("Critical"))
  assert_eq(messages[0].severity.value(), Some("Warning"))
  assert_eq(
    messages[0].message_args.value(),
    Some(["second", "first", "second"]),
  )
}

///|
test "task service and nested messages keep missing null zero and false" {
  let service = @moonredfish.parse_resource("/redfish/v1/TaskService", {
    "ServiceEnabled": false,
    "TaskAutoDeleteTimeoutMinutes": 0,
    "TaskMonitorAutoExpirySeconds": null,
    "Status": { "State": "FutureState", "Health": null },
  }).task_service()
  assert_eq(service.service_enabled.value(), Some(false))
  assert_eq(service.task_auto_delete_timeout_minutes.value(), Some(0))
  assert_true(service.task_monitor_auto_expiry_seconds is Null)
  assert_true(service.date_time is Missing)
  assert_eq(service.status.value().unwrap().state.value(), Some("FutureState"))
  assert_true(service.status.value().unwrap().health is Null)
  let task = @moonredfish.parse_resource("/redfish/v1/TaskService/Tasks/demo", {
    "PercentComplete": null,
    "Messages": [{ "MessageArgs": [], "Resolution": null }],
  }).task()
  assert_true(task.task_state is Missing)
  assert_true(task.percent_complete is Null)
  let message = task.messages.value().unwrap()[0]
  assert_eq(message.message_args.value(), Some([]))
  assert_true(message.message_id is Missing)
  assert_true(message.resolution is Null)
}

///|
test "task selected fields reject malformed types and keep existing integer bounds" {
  for
    raw in (
      [
        { "PercentComplete": -1 },
        { "PercentComplete": 0.5 },
        { "PercentComplete": 2147483648.0 },
        { "HidePayload": "true" },
        { "Messages": [null] },
        { "Messages": [{ "MessageArgs": [null] }] },
        { "Messages": [{ "MessageSeverity": 2 }] },
      ] : Array[Json]) {
    assert_true(
      try {
        ignore(
          @moonredfish.parse_resource("/redfish/v1/TaskService/Tasks/demo", raw).task(),
        )
        false
      } catch {
        @moonredfish.InvalidResponse(_) => true
        _ => false
      },
    )
  }
}
