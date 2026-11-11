///|
test "action info preserves reported metadata without applying constraints" {
  let parameter : Json = {
    "Name": "Example",
    "DataType": "FutureType",
    "DefaultValue": "{not parsed}",
    "AllowablePattern": "[not compiled",
    "AllowableNumbers": ["1:10:2", "PT1S:PT5S"],
    "AllowableValues": ["B", "A", "B"],
    "AllowableValueDescriptions": ["second"],
    "Required": true,
    "NoDefaultValue": true,
    "MaximumValue": 42,
    "Oem": { "Synthetic": true },
  }
  let resource = @moonredfish.parse_resource("/redfish/v1/ActionInfo/demo", {
    "Parameters": [parameter],
  })
  let info = resource.action_info()
  let p = info.parameters.value().unwrap()[0]
  assert_eq(info.resource.json, resource.json)
  assert_eq(p.json, parameter)
  assert_eq(p.default_value.value(), Some("{not parsed}"))
  assert_eq(p.allowable_pattern.value(), Some("[not compiled"))
  assert_eq(p.allowable_numbers.value(), Some(["1:10:2", "PT1S:PT5S"]))
  assert_eq(
    info.param_values("Example", "FutureType").value(),
    Some(["B", "A", "B"]),
  )
}

///|
test "action info query follows first matching name and type including wildcard" {
  let info = @moonredfish.parse_resource("/redfish/v1/ActionInfo/demo", {
    "Parameters": [
      {
        "Name": "Mode",
        "DataType": "Number",
        "AllowableValues": ["wrong-type"],
      },
      { "Name": "Mode", "DataType": "", "AllowableValues": [] },
      { "Name": "Mode", "DataType": "String", "AllowableValues": ["later"] },
    ],
  }).action_info()
  assert_eq(info.param_values("Mode", "String").value(), Some([]))
  let missing = @moonredfish.parse_resource("/redfish/v1/ActionInfo/demo", {
    "Parameters": [{ "Name": "Mode" }],
  }).action_info()
  assert_true(missing.param_values("Mode", "String") is Missing)
  let null = @moonredfish.parse_resource("/redfish/v1/ActionInfo/demo", {
    "Parameters": [{ "Name": "Mode", "AllowableValues": null }],
  }).action_info()
  assert_true(null.param_values("Mode", "String") is Null)
  assert_true(
    try {
      ignore(info.param_values("mode", "String"))
      false
    } catch {
      @moonredfish.InvalidResponse(_) => true
      _ => false
    },
  )
}

///|
test "action info distinguishes presence and rejects malformed selected parameters" {
  assert_true(
    @moonredfish.parse_resource("/redfish/v1/ActionInfo/demo", {}).action_info().parameters
    is Missing,
  )
  assert_true(
    @moonredfish.parse_resource("/redfish/v1/ActionInfo/demo", {
      "Parameters": null,
    }).action_info().parameters
    is Null,
  )
  for
    raw in (
      [
        { "Parameters": {} },
        { "Parameters": [null] },
        { "Parameters": [{ "Required": "true" }] },
        { "Parameters": [{ "AllowableValues": [null] }] },
      ] : Array[Json]) {
    assert_true(
      try {
        ignore(
          @moonredfish.parse_resource("/redfish/v1/ActionInfo/demo", raw).action_info(),
        )
        false
      } catch {
        @moonredfish.InvalidResponse(_) => true
        _ => false
      },
    )
  }
}
