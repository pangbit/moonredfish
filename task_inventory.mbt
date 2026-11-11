///|
/// Reported task message data; no registry lookup or resolution action is performed.
pub struct Message {
  json : Json
  message : Field[String]
  message_id : Field[String]
  message_severity : Field[String]
  resolution : Field[String]
  severity : Field[String]
  user_authentication_source : Field[String]
  username : Field[String]
  message_args : Field[Array[String]]
  related_properties : Field[Array[String]]
}

///|
fn parse_message(value : Json) -> Message raise RedfishError {
  require_object(value)
  {
    json: value,
    message: read_field(value, "Message", string_value),
    message_id: read_field(value, "MessageId", string_value),
    message_severity: read_field(value, "MessageSeverity", string_value),
    resolution: read_field(value, "Resolution", string_value),
    severity: read_field(value, "Severity", string_value),
    user_authentication_source: read_field(
      value, "UserAuthenticationSource", string_value,
    ),
    username: read_field(value, "Username", string_value),
    message_args: read_array(value, "MessageArgs", string_value),
    related_properties: read_array(value, "RelatedProperties", string_value),
  }
}

///|
/// Read-only reported TaskService data; raw JSON is retained.
pub struct TaskService {
  resource : Resource
  completed_task_overwrite_policy : Field[String]
  date_time : Field[String]
  life_cycle_event_on_task_state_change : Field[Bool]
  service_enabled : Field[Bool]
  task_auto_delete_timeout_minutes : Field[Int32]
  task_monitor_auto_expiry_seconds : Field[Int32]
  status : Field[Health]
}

///|
pub fn Resource::task_service(
  self : Resource,
) -> TaskService raise RedfishError {
  {
    resource: self,
    completed_task_overwrite_policy: read_field(
      self.json,
      "CompletedTaskOverWritePolicy",
      string_value,
    ),
    date_time: read_field(self.json, "DateTime", string_value),
    life_cycle_event_on_task_state_change: read_field(
      self.json,
      "LifeCycleEventOnTaskStateChange",
      bool_value,
    ),
    service_enabled: read_field(self.json, "ServiceEnabled", bool_value),
    task_auto_delete_timeout_minutes: read_field(
      self.json,
      "TaskAutoDeleteTimeoutMinutes",
      count_value,
    ),
    task_monitor_auto_expiry_seconds: read_field(
      self.json,
      "TaskMonitorAutoExpirySeconds",
      count_value,
    ),
    status: read_field(self.json, "Status", parse_health),
  }
}

///|
/// Read-only reported Task data; raw JSON is retained.
pub struct Task {
  resource : Resource
  end_time : Field[String]
  estimated_duration : Field[String]
  start_time : Field[String]
  task_monitor : Field[String]
  task_state : Field[String]
  task_status : Field[String]
  hide_payload : Field[Bool]
  percent_complete : Field[Int32]
  messages : Field[Array[Message]]
}

///|
pub fn Resource::task(self : Resource) -> Task raise RedfishError {
  {
    resource: self,
    end_time: read_field(self.json, "EndTime", string_value),
    estimated_duration: read_field(self.json, "EstimatedDuration", string_value),
    start_time: read_field(self.json, "StartTime", string_value),
    task_monitor: read_field(self.json, "TaskMonitor", string_value),
    task_state: read_field(self.json, "TaskState", string_value),
    task_status: read_field(self.json, "TaskStatus", string_value),
    hide_payload: read_field(self.json, "HidePayload", bool_value),
    percent_complete: read_field(self.json, "PercentComplete", count_value),
    messages: read_array(self.json, "Messages", parse_message),
  }
}
