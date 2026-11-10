///|
test "resource preserves optional and OEM fields" {
  let r = @moonredfish.parse_resource("/redfish/v1/Systems/1", {
    "Id": "1",
    "Name": "Synthetic node",
    "@odata.type": "#ComputerSystem.v1_20_0.ComputerSystem",
    "PowerState": "On",
    "Oem": { "Example": true },
  })
  assert_eq(r.id, Some("1"))
  assert_eq(r.name, Some("Synthetic node"))
  assert_eq(r.string("PowerState"), Some("On"))
  assert_eq(r.string("Missing"), None)
}

///|
test "resource does not invent missing optional fields" {
  let r = @moonredfish.parse_resource("/redfish/v1/", {})
  assert_eq(r.id, None)
  assert_eq(r.name, None)
  assert_eq(r.link("Systems"), None)
}

///|
test "collection parses pagination" {
  let c = @moonredfish.parse_collection({
    "Members": [{ "@odata.id": "/redfish/v1/Systems/1" }],
    "Members@odata.nextLink": "/redfish/v1/Systems?$skip=1",
  })
  assert_eq(c.members, ["/redfish/v1/Systems/1"])
  assert_eq(c.next_link, Some("/redfish/v1/Systems?$skip=1"))
}

///|
test "empty collection is valid" {
  let c = @moonredfish.parse_collection({ "Members": [] })
  assert_eq(c.members.length(), 0)
  assert_eq(c.next_link, None)
}

///|
test "malformed collections are not silently empty" {
  for
    value in [
      Json::null(),
      {},
      { "Members": null },
      { "Members": [{}] },
      { "Members": [], "Members@odata.nextLink": 3 },
    ] {
    let rejected = try {
      ignore(@moonredfish.parse_collection(value))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "cross origin and unsafe links are rejected" {
  for
    uri in [
      "https://example.invalid/redfish/v1/Systems", "//example.invalid/redfish/v1/",
      "/redfish/v10/", "/redfish/v1/../secret", "/redfish/v1/%2e%2e/secret", "/redfish/v1/\\secret",
      "/redfish/v1/#fragment", "/redfish/v1/\r\ninjected", "/redfish/v1//Systems",
    ] {
    let rejected = try {
      ignore(@moonredfish.parse_resource(uri, {}))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "client construction enforces transport policy without connecting" {
  ignore(@moonredfish.Client::new("https://bmc.example.invalid"))
  ignore(
    @moonredfish.Client::new("http://127.0.0.1:8080", allow_loopback_http=true),
  )
  ignore(
    @moonredfish.Client::new("http://[::1]:8080", allow_loopback_http=true),
  )
  for
    url in [
      "http://127.0.0.1:8080", "http://bmc.example.invalid", "https://user:password@example.invalid",
      "https://example.invalid/path", "https://example.invalid?x=1", "https://",
      "ftp://example.invalid",
    ] {
    let rejected = try {
      ignore(@moonredfish.Client::new(url))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let rejected = try {
    ignore(
      @moonredfish.Client::new(
        "http://example.invalid",
        allow_loopback_http=true,
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "client rejects unbounded options" {
  let rejected = try {
    ignore(@moonredfish.Client::new("https://example.invalid", timeout_ms=0))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let rejected = try {
    ignore(
      @moonredfish.Client::new("https://example.invalid", max_response_bytes=0),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let rejected = try {
    ignore(@moonredfish.Client::new("https://example.invalid", max_pages=0))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
