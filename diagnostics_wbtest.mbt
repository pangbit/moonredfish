///|
test "diagnostics retain only bounded machine identifiers" {
  let result = http_diagnostic(
    403, b"{\"error\":{\"code\":\"Base.1.18.GeneralError\",\"message\":\"private response\",\"@Message.ExtendedInfo\":[{\"MessageId\":\"Base.1.18.InsufficientPrivilege\",\"Message\":\"secret\",\"MessageArgs\":[\"private host\"],\"Resolution\":\"private instruction\"},{\"MessageId\":\"Base.1.18.InsufficientPrivilege\"},{\"MessageId\":\"bad\\nidentifier\"}]}}",
  )
  assert_eq(result.status, 403)
  assert_eq(result.code, Some("Base.1.18.GeneralError"))
  assert_eq(result.message_ids, ["Base.1.18.InsufficientPrivilege"])
}

///|
test "malformed diagnostic payload preserves HTTP status" {
  for
    data in [
      b"not JSON", b"[]", b"{}", b"{\"error\":null}", b"{\"error\":{},\"error\":{}}",
    ] {
    let result = http_diagnostic(502, data)
    assert_eq(result.status, 502)
    assert_eq(result.code, None)
    assert_eq(result.message_ids.length(), 0)
  }
}

///|
test "diagnostic identifiers reject controls spaces and oversized values" {
  assert_eq(
    diagnostic_identifier(Some("valid.Registry-1_Code")),
    Some("valid.Registry-1_Code"),
  )
  assert_eq(diagnostic_identifier(Some("password with spaces")), None)
  assert_eq(diagnostic_identifier(Some("bad\u{7f}")), None)
  assert_eq(diagnostic_identifier(Some("x".repeat(257))), None)
  assert_eq(diagnostic_identifier(Some("")), None)
}
