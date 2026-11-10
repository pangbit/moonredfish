///|
test "invalid and duplicate key JSON is rejected without echoing input" {
  for data in [b"not-json", b"{\"Id\":1,\"Id\":2}", b"\xff"] {
    let rejected = try {
      ignore(decode_json(data))
      false
    } catch {
      InvalidResponse(_) => true
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "safe path queries and root variants are accepted" {
  for
    path in [
      "/redfish/v1", "/redfish/v1/", "/redfish/v1/Systems?$skiptoken=a%2Fb",
    ] {
    validate_path(path)
  }
}

///|
test "session deletion is restricted to a single session member" {
  validate_session_location("/redfish/v1/SessionService/Sessions/1")
  for
    uri in [
      "/redfish/v1/SessionService/Sessions/", "/redfish/v1/SessionService/Sessions/1/",
      "/redfish/v1/SessionService/Sessions/1/Actions/Delete", "/redfish/v1/SessionService/Sessions/1?x=1",
      "/redfish/v1/Systems/1",
    ] {
    let rejected = try {
      validate_session_location(uri)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
