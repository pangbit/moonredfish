///|
/// Reported action parameter metadata; does not validate or construct action payloads.
pub struct ActionInfoParameter {
  json : Json
  name : Field[String]
  data_type : Field[String]
  default_value : Field[String]
  object_data_type : Field[String]
  allowable_pattern : Field[String]
  allowable_numbers : Field[Array[String]]
  allowable_value_descriptions : Field[Array[String]]
  allowable_values : Field[Array[String]]
  no_default_value : Field[Bool]
  required : Field[Bool]
}

///|
fn parse_action_info_parameter(
  json : Json,
) -> ActionInfoParameter raise RedfishError {
  require_object(json)
  {
    json,
    name: read_field(json, "Name", string_value),
    data_type: read_field(json, "DataType", string_value),
    default_value: read_field(json, "DefaultValue", string_value),
    object_data_type: read_field(json, "ObjectDataType", string_value),
    allowable_pattern: read_field(json, "AllowablePattern", string_value),
    allowable_numbers: read_array(json, "AllowableNumbers", string_value),
    allowable_value_descriptions: read_array(
      json, "AllowableValueDescriptions", string_value,
    ),
    allowable_values: read_array(json, "AllowableValues", string_value),
    no_default_value: read_field(json, "NoDefaultValue", bool_value),
    required: read_field(json, "Required", bool_value),
  }
}

///|
pub struct ActionInfo {
  resource : Resource
  parameters : Field[Array[ActionInfoParameter]]
}

///|
pub fn Resource::action_info(self : Resource) -> ActionInfo raise RedfishError {
  {
    resource: self,
    parameters: read_array(self.json, "Parameters", parse_action_info_parameter),
  }
}

///|
/// First matching name/type, with an absent/null/empty reported type acting as a wildcard.
/// Returns the selected AllowableValues presence unchanged; never synthesizes defaults.
pub fn ActionInfo::param_values(
  self : ActionInfo,
  name : String,
  data_type : String,
) -> Field[Array[String]] raise RedfishError {
  if self.parameters is Value(parameters) {
    for parameter in parameters {
      let reported_type = parameter.data_type.value().unwrap_or("")
      if parameter.name.value().unwrap_or("") == name &&
        (reported_type.is_empty() || reported_type == data_type) {
        return parameter.allowable_values
      }
    }
  }
  raise InvalidResponse("no matching ActionInfo parameter")
}
