///|
test "wire integer fields reject fractions rounded to integers" {
  for
    text in [
      "1.0000000000000001", "9007199254740991.1", "1e-9999", "-1e-9999", "0.99999999999999999",
    ] {
    let raw = "{\"CapacityBytes\":\{text}}"
    assert_true(
      try {
        ignore(
          parse_resource("/redfish/v1/Drives/0", decode_json(@utf8.encode(raw))).drive(),
        )
        false
      } catch {
        InvalidResponse(_) => true
        _ => false
      },
      msg="fractional capacity must fail: \{text}",
    )
  }
}

///|
test "wire count fields reject fractions lost to floating point rounding" {
  let raw = decode_json(
    b"{\"ProcessorSummary\":{\"Count\":1.0000000000000001}}",
  )
  assert_true(
    try {
      ignore(parse_resource("/redfish/v1/Systems/0", raw).system_info())
      false
    } catch {
      InvalidResponse(_) => true
      _ => false
    },
  )
}

///|
test "wire integers preserve accepted exact decimal and exponent forms" {
  for
    text in [
      "0", "-0.0", "0e-999999999999999999999", "1.0", "100e-2", "1e3", "1.00e+0",
      "9007199254740991",
    ] {
    let raw = "{\"CapacityBytes\":\{text}}"
    ignore(
      parse_resource("/redfish/v1/Drives/0", decode_json(@utf8.encode(raw))).drive(),
    )
  }
}
