///|
test "PCIe device keeps raw inventory and exact lane counts" {
  let raw : Json = {
    "Manufacturer": "Synthetic",
    "Model": "Synthetic NIC",
    "DeviceType": "FutureDeviceType",
    "LocationIndicatorActive": false,
    "ReadyToRemove": false,
    "PCIeInterface": {
      "LanesInUse": 16777217,
      "MaxLanes": null,
      "PCIeType": "FutureGen",
      "Oem": { "Synthetic": true },
    },
    "Status": { "State": "Absent" },
    "CXLDevice": { "Synthetic": true },
  }
  let device = @moonredfish.parse_resource("/redfish/v1/PCIeDevices/0", raw).pcie_device()
  assert_eq(device.resource.json, raw)
  assert_eq(device.device_type.value(), Some("FutureDeviceType"))
  assert_eq(device.ready_to_remove.value(), Some(false))
  let interface = device.pcie_interface.value().unwrap()
  assert_eq(interface.lanes_in_use.value(), Some(16777217))
  assert_true(interface.max_lanes is Null)
  assert_true(interface.max_pcie_type is Missing)
  assert_eq(interface.pcie_type.value(), Some("FutureGen"))
  guard raw is { "PCIeInterface": raw_interface, .. } else {
    fail("test fixture")
  }
  assert_eq(interface.json, raw_interface)
  assert_eq(device.status.value().unwrap().state.value(), Some("Absent"))
}

///|
test "PCIe functions retain hexadecimal strings zero and false without inference" {
  let raw : Json = {
    "VendorId": "0x1abc",
    "DeviceId": "00Af",
    "ClassCode": "020000",
    "ARIFunctionNumber": "0x09",
    "ARIModeEnabled": false,
    "BusNumber": "0x02",
    "FunctionId": 0,
    "Enabled": false,
    "FunctionProtocol": "FutureProtocol",
    "FunctionType": null,
  }
  let f = @moonredfish.parse_resource("/redfish/v1/PCIeFunctions/0", raw).pcie_function()
  assert_eq(f.resource.json, raw)
  assert_eq(f.vendor_id.value(), Some("0x1abc"))
  assert_eq(f.device_id.value(), Some("00Af"))
  assert_eq(f.function_id.value(), Some(0))
  assert_eq(f.enabled.value(), Some(false))
  assert_true(f.function_number is Missing)
  assert_true(f.function_type is Null)
  assert_eq(f.function_protocol.value(), Some("FutureProtocol"))
}

///|
test "PCIe lane fields preserve strict integers and object shape" {
  for
    raw in (
      [
        { "PCIeInterface": [] },
        { "PCIeInterface": { "LanesInUse": "8" } },
        { "PCIeInterface": { "LanesInUse": 1.5 } },
        { "PCIeInterface": { "MaxLanes": -1 } },
        { "PCIeInterface": { "MaxLanes": 2147483648.0 } },
        { "ReadyToRemove": "false" },
      ] : Array[Json]) {
    assert_true(
      try {
        ignore(
          @moonredfish.parse_resource("/redfish/v1/PCIeDevices/0", raw).pcie_device(),
        )
        false
      } catch {
        @moonredfish.InvalidResponse(_) => true
        _ => false
      },
    )
  }
}
