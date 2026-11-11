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
