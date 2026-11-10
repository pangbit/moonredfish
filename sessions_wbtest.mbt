///|
test "session collection discovery follows only safe advertised links" {
  assert_eq(
    session_collection_link({
      "Links": { "Sessions": { "@odata.id": "/redfish/v1/Sessions" } },
    }),
    Some("/redfish/v1/Sessions"),
  )
  assert_eq(session_collection_link({}), None)
  assert_eq(session_collection_link({ "Links": {} }), None)
  let invalid : Array[Json] = [
    {
      "Links": {
        "Sessions": {
          "@odata.id": "https://example.invalid/redfish/v1/Sessions",
        },
      },
    },
    { "Links": { "Sessions": { "@odata.id": "/redfish/v1/Sessions?x=1" } } },
    { "Links": false },
  ]
  for root in invalid {
    assert_true(
      try {
        ignore(session_collection_link(root))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "session location must be a direct child of the discovered collection" {
  validate_session_location(
    "/redfish/v1/Sessions/1",
    collection="/redfish/v1/Sessions",
  )
  validate_session_location(
    "/redfish/v1/Sessions/1",
    collection="/redfish/v1/Sessions/",
  )
  assert_true(
    try {
      validate_session_location(
        "/redfish/v1/SessionService/Sessions/1",
        collection="/redfish/v1/Sessions",
      )
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      validate_session_location(
        "/redfish/v1/Sessions",
        collection="/redfish/v1/Sessions",
      )
      false
    } catch {
      _ => true
    },
  )
}
