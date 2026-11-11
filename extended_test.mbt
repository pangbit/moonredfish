///|
test "drive and volume preserve null zero identifiers and unknown enums" {
  let raw : Json = {
    "CapacityBytes": 0,
    "FailurePredicted": false,
    "Protocol": "FutureProtocol",
    "MediaType": null,
    "SerialNumber": "synthetic-drive",
    "RAIDType": "FutureRAID",
    "Status": { "Health": "FutureHealth" },
    "Oem": { "Synthetic": true },
  }
  let r = @moonredfish.parse_resource("/redfish/v1/Drives/0", raw)
  let d = r.drive()
  assert_eq(d.capacity_bytes.value(), Some(0.0))
  assert_eq(d.failure_predicted.value(), Some(false))
  assert_true(d.media_type is Null)
  assert_true(d.revision is Missing)
  assert_eq(d.protocol.value(), Some("FutureProtocol"))
  assert_eq(d.resource.json, raw)
  assert_eq(r.volume().raid_type.value(), Some("FutureRAID"))
  assert_true(r.volume().volume_type is Missing)
  assert_true(r.storage().status is Value(_))
}

///|
test "network views distinguish false null missing and unknown link state" {
  let raw : Json = {
    "MACAddress": "02:00:00:00:00:01",
    "InterfaceEnabled": false,
    "FullDuplex": null,
    "SpeedMbps": 0,
    "LinkStatus": "FutureLinkState",
    "Manufacturer": "Synthetic",
  }
  let r = @moonredfish.parse_resource("/redfish/v1/Network/0", raw)
  let n = r.ethernet_interface()
  assert_eq(n.mac_address.value(), Some("02:00:00:00:00:01"))
  assert_eq(n.interface_enabled.value(), Some(false))
  assert_true(n.full_duplex is Null)
  assert_true(n.permanent_mac_address is Missing)
  assert_eq(n.speed_mbps.value(), Some(0.0))
  assert_eq(n.link_status.value(), Some("FutureLinkState"))
  assert_eq(r.network_adapter().manufacturer.value(), Some("Synthetic"))
}

///|
test "logs firmware and BIOS retain structured values without interpreting permissions" {
  let attributes : Json = {
    "BootMode": "Uefi",
    "Retries": 0,
    "Enabled": false,
    "Unset": null,
  }
  let raw : Json = {
    "ServiceEnabled": false,
    "MaxNumberOfRecords": 0,
    "OverWritePolicy": "FuturePolicy",
    "EntryType": "FutureEntryType",
    "Message": "Synthetic private message",
    "MessageArgs": ["Synthetic argument"],
    "Severity": null,
    "Updateable": false,
    "Version": "synthetic-v1",
    "Attributes": attributes,
    "AttributeRegistry": "SyntheticRegistry",
  }
  let r = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", raw)
  assert_eq(r.log_service().max_number_of_records.value(), Some(0.0))
  assert_eq(r.log_service().service_enabled.value(), Some(false))
  assert_eq(r.log_entry().message_args.value(), Some(["Synthetic argument"]))
  assert_true(r.log_entry().severity is Null)
  assert_true(r.log_entry().created is Missing)
  assert_eq(r.software_inventory().updateable.value(), Some(false))
  assert_eq(r.bios().attributes.value(), Some(attributes))
  assert_eq(r.bios().resource.json, raw)
}

///|
test "extended views reject malformed fields and out of range integer numbers" {
  for
    raw in (
      [
        { "CapacityBytes": -1 },
        { "CapacityBytes": 1.5 },
        { "CapacityBytes": 9007199254740992.0 },
        { "CapacityBytes": "1" },
        { "FailurePredicted": 0 },
        { "Protocol": true },
      ] : Array[Json]) {
    assert_true(
      try {
        ignore(@moonredfish.parse_resource("/redfish/v1/Drives/0", raw).drive())
        false
      } catch {
        @moonredfish.InvalidResponse(_) => true
        _ => false
      },
    )
  }
  let r = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {
    "InterfaceEnabled": "true",
    "ServiceEnabled": 1,
    "Updateable": [],
    "Attributes": [],
    "MessageArgs": [null],
    "Status": false,
  })
  assert_true(
    try {
      ignore(r.ethernet_interface())
      false
    } catch {
      @moonredfish.InvalidResponse(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(r.network_adapter())
      false
    } catch {
      @moonredfish.InvalidResponse(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(r.log_service())
      false
    } catch {
      @moonredfish.InvalidResponse(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(r.log_entry())
      false
    } catch {
      @moonredfish.InvalidResponse(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(r.software_inventory())
      false
    } catch {
      @moonredfish.InvalidResponse(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(r.bios())
      false
    } catch {
      @moonredfish.InvalidResponse(_) => true
      _ => false
    },
  )
}

///|
test "BIOS object and log arguments keep all three states" {
  let absent = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {})
  let null = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {
    "Attributes": null,
    "MessageArgs": null,
  })
  let empty = @moonredfish.parse_resource("/redfish/v1/Synthetic/0", {
    "Attributes": {},
    "MessageArgs": [],
  })
  assert_true(absent.bios().attributes is Missing)
  assert_true(null.bios().attributes is Null)
  assert_eq(empty.bios().attributes.value(), Some({}))
  assert_true(absent.log_entry().message_args is Missing)
  assert_true(null.log_entry().message_args is Null)
  assert_eq(empty.log_entry().message_args.value(), Some([]))
}
