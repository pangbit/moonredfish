///|
async fn check_inventory(endpoint : String) -> Unit {
  let c = @moonredfish.Client::new(endpoint, allow_loopback_http=true)
  let owner = @moonredfish.parse_resource("/redfish/v1/Systems/demo", {
    "Processors": { "@odata.id": "/redfish/v1/Inventory/Processors" },
    "Memory": { "@odata.id": "/redfish/v1/Inventory/Empty" },
    "Thermal": null,
  })
  guard c.processors(owner) is Value(processors) else {
    fail("missing processors")
  }
  assert_eq(processors.length(), 2)
  assert_eq(processors[0].resource.id, Some("0"))
  assert_eq(processors[1].total_cores.value(), Some(0))
  guard c.memory(owner) is Value(memory) else { fail("missing memory") }
  assert_eq(memory.length(), 0)
  assert_true(c.thermal(owner) is Null)
  assert_true(c.power(owner) is Missing)
  assert_true(c.thermal_subsystem(owner) is Missing)
  assert_true(c.power_subsystem(owner) is Missing)
  let denied = @moonredfish.parse_resource("/redfish/v1/Systems/demo", {
    "Processors": { "@odata.id": "/redfish/v1/Forbidden" },
    "Thermal": { "@odata.id": "/redfish/v1/Inventory/Missing" },
    "Power": { "@odata.id": "https://example.invalid/never-follow" },
  })
  assert_true(
    try {
      ignore(c.processors(denied))
      false
    } catch {
      @moonredfish.HttpStatus(403) => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(c.thermal(denied))
      false
    } catch {
      @moonredfish.HttpStatus(404) => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(c.power(denied))
      false
    } catch {
      @moonredfish.InvalidPath => true
      _ => false
    },
  )
  let broken = @moonredfish.parse_resource("/redfish/v1/Systems/demo", {
    "Processors": { "@odata.id": "/redfish/v1/Inventory/Broken" },
  })
  assert_true(
    try {
      ignore(c.processors(broken))
      false
    } catch {
      @moonredfish.HttpStatus(404) => true
      _ => false
    },
  )
  let member_limited = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    max_members=1,
  )
  assert_true(
    try {
      ignore(member_limited.processors(owner))
      false
    } catch {
      @moonredfish.MemberLimit => true
      _ => false
    },
  )
  let page_limited = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    max_pages=1,
  )
  assert_true(
    try {
      ignore(page_limited.processors(owner))
      false
    } catch {
      @moonredfish.PageLimit => true
      _ => false
    },
  )
  let byte_limited = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    max_total_response_bytes=300,
  )
  assert_true(
    try {
      ignore(byte_limited.processors(owner))
      false
    } catch {
      @moonredfish.TotalResponseTooLarge => true
      _ => false
    },
  )
  let slow = @moonredfish.parse_resource("/redfish/v1/Chassis/demo", {
    "Sensors": { "@odata.id": "/redfish/v1/SlowPages?page=1" },
  })
  let operation_limited = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    timeout_ms=1000,
    operation_timeout_ms=100,
  )
  assert_true(
    try {
      ignore(operation_limited.sensors(slow))
      false
    } catch {
      @moonredfish.OperationTimeout => true
      _ => false
    },
  )
}
