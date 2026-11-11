///|
fn action_parameter_json(p : @moonredfish.ActionInfoParameter) -> Json {
  {
    "Name": parity_value(p.name),
    "DataType": parity_value(p.data_type),
    "DefaultValue": parity_value(p.default_value),
    "ObjectDataType": parity_value(p.object_data_type),
    "AllowablePattern": parity_value(p.allowable_pattern),
    "AllowableNumbers": parity_value(p.allowable_numbers),
    "AllowableValueDescriptions": parity_value(p.allowable_value_descriptions),
    "AllowableValues": parity_value(p.allowable_values),
    "NoDefaultValue": parity_value(p.no_default_value),
    "Required": parity_value(p.required),
  }
}

///|
fn action_info_json(info : @moonredfish.ActionInfo) -> Json {
  {
    "uri": @json.to_json(info.resource.uri),
    "id": optional(info.resource.id),
    "fields": {
      "Parameters": boot_items(info.parameters, action_parameter_json),
    },
  }
}

///|
fn action_info_result(
  info : @moonredfish.Field[@moonredfish.ActionInfo],
) -> Json {
  match info {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(info) => { "state": "value", "value": action_info_json(info) }
  }
}

///|
async fn action_info_inventory(c : @moonredfish.Client) -> Json {
  guard c.get("/redfish/v1/ActionInfoTests").json
    is { "Cases": Array(cases), .. } else {
    fail("invalid action info manifest")
  }
  let out : Map[String, Json] = Map([])
  for probe in cases {
    guard probe
      is {
        "ID": String(id),
        "URI": String(uri),
        "Kind": String(kind),
        "Name": String(name),
        "Type": String(data_type),
        "Action": String(action),
        ..
      } else {
      fail("invalid action info case")
    }
    out[id] = try {
      let owner = c.get(uri)
      let result = match kind {
        "info" => action_info_json(owner.action_info())
        "query" =>
          parity_value(owner.action_info().param_values(name, data_type))
        "system_reset" | "manager_reset" | "insert_info" =>
          action_info_result(c.action_info(owner, action))
        _ => fail("invalid action info operation")
      }
      { "ok": true, "error": "", "value": result }
    } catch {
      @moonredfish.InvalidResponse(_) =>
        { "ok": false, "error": "invalid_response", "value": @json.null }
      @moonredfish.InvalidPath =>
        { "ok": false, "error": "invalid_path", "value": @json.null }
      @moonredfish.DetailedHttpStatus(_) =>
        { "ok": false, "error": "http", "value": @json.null }
      _ => fail("unexpected action info fixture error")
    }
  }
  { "cases": @json.to_json(out) }
}
