///|
/// Reads only the named Actions entry's @Redfish.ActionInfo annotation, never its target.
/// The caller selects the exact advertised action name. No action is invoked.
pub async fn Client::action_info(
  self : Client,
  owner : Resource,
  action : String,
) -> Field[ActionInfo] {
  let path = match read_field(owner.json, "Actions", object_value) {
    Missing => Missing
    Null => Null
    Value(actions) =>
      nested_field(actions, action, "@Redfish.ActionInfo", string_value)
  }
  match path {
    Missing => Missing
    Null => Null
    Value(path) => {
      let budget = ReadBudget::{ remaining: self.max_total_response_bytes, }
      Value(
        @async.with_timeout(
          self.operation_timeout_ms,
          async fn() { self.read_resource(path, budget~).action_info() },
          error=OperationTimeout,
        ),
      )
    }
  }
}
