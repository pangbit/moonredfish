///|
async fn check_extended(endpoint : String) -> Unit {
  let c = @moonredfish.Client::new(endpoint, allow_loopback_http=true)
  let absent = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {})
  let null_owner = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {
    "Storage": null,
    "Drives": null,
    "Volumes": null,
    "EthernetInterfaces": null,
    "NetworkAdapters": null,
    "LogServices": null,
    "Entries": null,
    "UpdateService": null,
    "FirmwareInventory": null,
    "Bios": null,
  })
  assert_true(c.storage(absent) is Missing)
  assert_true(c.drives(absent) is Missing)
  assert_true(c.volumes(absent) is Missing)
  assert_true(c.ethernet_interfaces(absent) is Missing)
  assert_true(c.network_adapters(absent) is Missing)
  assert_true(c.log_services(absent) is Missing)
  assert_true(c.log_entries(absent) is Missing)
  assert_true(c.update_service(absent) is Missing)
  assert_true(c.firmware_inventory(absent) is Missing)
  assert_true(c.bios(absent) is Missing)
  assert_true(c.storage(null_owner) is Null)
  assert_true(c.drives(null_owner) is Null)
  assert_true(c.volumes(null_owner) is Null)
  assert_true(c.ethernet_interfaces(null_owner) is Null)
  assert_true(c.network_adapters(null_owner) is Null)
  assert_true(c.log_services(null_owner) is Null)
  assert_true(c.log_entries(null_owner) is Null)
  assert_true(c.update_service(null_owner) is Null)
  assert_true(c.firmware_inventory(null_owner) is Null)
  assert_true(c.bios(null_owner) is Null)
  let empty = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {
    "Drives": [],
  })
  guard c.drives(empty) is Value(drives) else {
    fail("expected empty drive array")
  }
  assert_eq(drives.length(), 0)
  let duplicate = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {
    "Drives": [
      { "@odata.id": "/redfish/v1/Extended/Drive0" },
      { "@odata.id": "/redfish/v1/Extended/Drive0" },
    ],
  })
  guard c.drives(duplicate) is Value(drives) else {
    fail("expected drive array")
  }
  assert_eq(drives.length(), 1)
  assert_eq(drives[0].capacity_bytes.value(), Some(0.0))
  assert_eq(drives[0].failure_predicted.value(), Some(false))
  for raw in ([{ "Drives": {} }, { "Drives": [null] }] : Array[Json]) {
    assert_true(
      try {
        ignore(
          c.drives(@moonredfish.parse_resource("/redfish/v1/Synthetic/0", raw)),
        )
        false
      } catch {
        @moonredfish.InvalidResponse(_) => true
        _ => false
      },
    )
  }
  let unsafe_links = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {
    "Drives": [
      { "@odata.id": "/redfish/v1/NeverRequested" },
      { "@odata.id": "https://example.invalid/never-follow" },
    ],
  })
  assert_true(
    try {
      ignore(c.drives(unsafe_links))
      false
    } catch {
      @moonredfish.InvalidPath => true
      _ => false
    },
  )
  let owner = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {
    "Drives": [
      { "@odata.id": "/redfish/v1/Extended/Drive0" },
      { "@odata.id": "/redfish/v1/Extended/Drive1" },
    ],
  })
  let member_limited = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    max_members=1,
  )
  assert_true(
    try {
      ignore(member_limited.drives(owner))
      false
    } catch {
      @moonredfish.MemberLimit => true
      _ => false
    },
  )
  let byte_limited = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    max_total_response_bytes=100,
  )
  assert_true(
    try {
      ignore(byte_limited.drives(owner))
      false
    } catch {
      @moonredfish.TotalResponseTooLarge => true
      _ => false
    },
  )
  let slow = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {
    "Drives": [
      { "@odata.id": "/redfish/v1/Extended/SlowDrive0" },
      { "@odata.id": "/redfish/v1/Extended/SlowDrive1" },
    ],
  })
  let timed = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    timeout_ms=1000,
    operation_timeout_ms=100,
  )
  assert_true(
    try {
      ignore(timed.drives(slow))
      false
    } catch {
      @moonredfish.OperationTimeout => true
      _ => false
    },
  )
  let broken = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {
    "Drives": [
      { "@odata.id": "/redfish/v1/Extended/Drive0" },
      { "@odata.id": "/redfish/v1/Inventory/Missing" },
    ],
    "Storage": { "@odata.id": "/redfish/v1/Forbidden" },
    "Bios": { "@odata.id": "/redfish/v1/Inventory/Missing" },
  })
  assert_true(
    try {
      ignore(c.drives(broken))
      false
    } catch {
      @moonredfish.HttpStatus(404) => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(c.storage(broken))
      false
    } catch {
      @moonredfish.HttpStatus(403) => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(c.bios(broken))
      false
    } catch {
      @moonredfish.HttpStatus(404) => true
      _ => false
    },
  )
  let log = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {
    "Entries": { "@odata.id": "/redfish/v1/Inventory/Processors" },
  })
  guard c.log_entries(log) is Value(entries) else {
    fail("expected log entries")
  }
  assert_eq(entries.length(), 2)
  assert_true(
    try {
      ignore(member_limited.log_entries(log))
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
      ignore(page_limited.log_entries(log))
      false
    } catch {
      @moonredfish.PageLimit => true
      _ => false
    },
  )
  let log_bytes = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    max_total_response_bytes=300,
  )
  assert_true(
    try {
      ignore(log_bytes.log_entries(log))
      false
    } catch {
      @moonredfish.TotalResponseTooLarge => true
      _ => false
    },
  )
  println(
    "extended inventory: three-state links, drives and shared traversal budgets passed",
  )
}
