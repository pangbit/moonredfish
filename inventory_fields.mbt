///|
fn require_object(value : Json) -> Unit raise RedfishError {
  guard value is Object(_) else {
    raise InvalidResponse("expected inventory object")
  }
}

///|
fn[T] read_field(
  value : Json,
  key : String,
  decode : (Json) -> T raise RedfishError,
) -> Field[T] raise RedfishError {
  guard value is Object(fields) else {
    raise InvalidResponse("expected inventory object")
  }
  match fields.get(key) {
    None => Missing
    Some(Null) => Null
    Some(value) => Value(decode(value))
  }
}

///|
fn[T] nested_field(
  value : Json,
  parent : String,
  key : String,
  decode : (Json) -> T raise RedfishError,
) -> Field[T] raise RedfishError {
  match
    read_field(value, parent, value => {
      require_object(value)
      value
    }) {
    Missing => Missing
    Null => Null
    Value(object) => read_field(object, key, decode)
  }
}

///|
fn string_value(value : Json) -> String raise RedfishError {
  guard value is String(value) else {
    raise InvalidResponse("expected inventory string")
  }
  value
}

///|
fn number_value(value : Json) -> Double raise RedfishError {
  guard value is Number(value, ..) && value.is_finite() else {
    raise InvalidResponse("expected finite inventory number")
  }
  value
}

///|
fn count_value(value : Json) -> Int32 raise RedfishError {
  let value = number_value(value)
  guard value >= 0 &&
    value <= 2147483647.0 &&
    value == value.to_int().to_double() else {
    raise InvalidResponse("expected nonnegative inventory count")
  }
  value.to_int()
}

///|
fn[T] read_array(
  value : Json,
  key : String,
  decode : (Json) -> T raise RedfishError,
) -> Field[Array[T]] raise RedfishError {
  read_field(value, key, value => {
    guard value is Array(items) else {
      raise InvalidResponse("expected inventory array")
    }
    items.map(decode)
  })
}

///|
fn bool_value(value : Json) -> Bool raise RedfishError {
  match value {
    True => true
    False => false
    _ => raise InvalidResponse("expected inventory boolean")
  }
}

///|
fn object_value(value : Json) -> Json raise RedfishError {
  require_object(value)
  value
}

///|
/// JSON numbers beyond the exact Double integer range must not silently round.
/// Original JSON remains available for applications requiring a wider integer range.
fn safe_integer_value(value : Json) -> Double raise RedfishError {
  let number = number_value(value)
  guard number >= 0.0 &&
    number <= 9007199254740991.0 &&
    number == number.to_int64().to_double() else {
    raise InvalidResponse("expected nonnegative exact inventory integer")
  }
  number
}
