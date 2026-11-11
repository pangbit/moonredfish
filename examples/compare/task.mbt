///|
fn task_message_json(item : @moonredfish.Message) -> Json {
  {
    "Message": parity_value(item.message),
    "MessageId": parity_value(item.message_id),
    "MessageSeverity": parity_value(item.message_severity),
    "Resolution": parity_value(item.resolution),
    "Severity": parity_value(item.severity),
    "UserAuthenticationSource": parity_value(item.user_authentication_source),
    "Username": parity_value(item.username),
    "MessageArgs": parity_value(item.message_args),
    "RelatedProperties": parity_value(item.related_properties),
  }
}

///|
fn task_task_service_json(item : @moonredfish.TaskService) -> Json {
  {
    "uri": @json.to_json(item.resource.uri),
    "id": optional(item.resource.id),
    "fields": {
      "CompletedTaskOverWritePolicy": parity_value(
        item.completed_task_overwrite_policy,
      ),
      "DateTime": parity_value(item.date_time),
      "LifeCycleEventOnTaskStateChange": parity_value(
        item.life_cycle_event_on_task_state_change,
      ),
      "ServiceEnabled": parity_value(item.service_enabled),
      "TaskAutoDeleteTimeoutMinutes": parity_value(
        item.task_auto_delete_timeout_minutes,
      ),
      "TaskMonitorAutoExpirySeconds": parity_value(
        item.task_monitor_auto_expiry_seconds,
      ),
      "Status": pcie_health(item.status),
    },
  }
}

///|
fn task_task_json(item : @moonredfish.Task) -> Json {
  {
    "uri": @json.to_json(item.resource.uri),
    "id": optional(item.resource.id),
    "fields": {
      "EndTime": parity_value(item.end_time),
      "EstimatedDuration": parity_value(item.estimated_duration),
      "StartTime": parity_value(item.start_time),
      "TaskMonitor": parity_value(item.task_monitor),
      "TaskState": parity_value(item.task_state),
      "TaskStatus": parity_value(item.task_status),
      "HidePayload": parity_value(item.hide_payload),
      "PercentComplete": parity_value(item.percent_complete),
      "Messages": task_items(item.messages, task_message_json),
    },
  }
}

///|
fn task_entity_json(item : @moonredfish.Resource) -> Json {
  {
    "uri": @json.to_json(item.uri),
    "id": optional(item.id),
    "name": optional(item.name),
  }
}

///|
fn[T] task_items(
  items : @moonredfish.Field[Array[T]],
  project : (T) -> Json,
) -> Json {
  match items {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(items) =>
      { "state": "value", "value": @json.to_json(items.map(project)) }
  }
}

///|
async fn task_inventory(c : @moonredfish.Client) -> Json {
  guard c.get("/redfish/v1/TaskTests").json is { "Cases": Array(cases), .. } else {
    fail("invalid task manifest")
  }
  let out : Map[String, Json] = Map([])
  for probe in cases {
    guard probe
      is { "ID": String(id), "URI": String(uri), "Kind": String(kind), .. } else {
      fail("invalid task case")
    }
    out[id] = try {
      let owner = c.get(uri)
      let result = match kind {
        "task" => task_task_json(owner.task())
        "service" => task_task_service_json(owner.task_service())
        "task_service" =>
          match c.task_service(owner) {
            Missing => { "state": "missing" }
            Null => { "state": "null" }
            Value(item) =>
              { "state": "value", "value": task_task_service_json(item) }
          }
        "tasks" => task_items(c.tasks(owner), task_task_json)
        "sub_tasks" => task_items(c.sub_tasks(owner), task_task_json)
        "created" =>
          task_items(c.task_created_resources(owner), task_entity_json)
        _ => fail("invalid task operation")
      }
      { "ok": true, "error": "", "value": result }
    } catch {
      @moonredfish.InvalidResponse(_) =>
        { "ok": false, "error": "invalid_response", "value": @json.null }
      @moonredfish.InvalidPath =>
        { "ok": false, "error": "invalid_path", "value": @json.null }
      @moonredfish.DetailedHttpStatus(_) =>
        { "ok": false, "error": "http", "value": @json.null }
      _ => fail("unexpected task fixture error")
    }
  }
  { "cases": @json.to_json(out) }
}
