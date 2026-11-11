///|
fn pcie_health(field : @moonredfish.Field[@moonredfish.Health]) -> Json {
  match field {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(item) =>
      {
        "state": "value",
        "value": {
          "State": parity_value(item.state),
          "Health": parity_value(item.health),
          "HealthRollup": parity_value(item.health_rollup),
        },
      }
  }
}

///|
fn pcie_interface_json(
  field : @moonredfish.Field[@moonredfish.PCIeInterface],
) -> Json {
  match field {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(item) =>
      {
        "state": "value",
        "value": {
          "LanesInUse": parity_value(item.lanes_in_use),
          "MaxLanes": parity_value(item.max_lanes),
          "MaxPCIeType": parity_value(item.max_pcie_type),
          "PCIeType": parity_value(item.pcie_type),
        },
      }
  }
}

///|
fn pcie_device_json(item : @moonredfish.PCIeDevice) -> Json {
  {
    "uri": @json.to_json(item.resource.uri),
    "id": optional(item.resource.id),
    "fields": {
      "AssetTag": parity_value(item.asset_tag),
      "DeviceType": parity_value(item.device_type),
      "FirmwareVersion": parity_value(item.firmware_version),
      "Manufacturer": parity_value(item.manufacturer),
      "Model": parity_value(item.model),
      "PartNumber": parity_value(item.part_number),
      "SKU": parity_value(item.sku),
      "SerialNumber": parity_value(item.serial_number),
      "SparePartNumber": parity_value(item.spare_part_number),
      "StagedVersion": parity_value(item.staged_version),
      "UUID": parity_value(item.uuid),
      "LocationIndicatorActive": parity_value(item.location_indicator_active),
      "ReadyToRemove": parity_value(item.ready_to_remove),
      "PCIeInterface": pcie_interface_json(item.pcie_interface),
      "Status": pcie_health(item.status),
    },
  }
}

///|
fn pcie_function_json(item : @moonredfish.PCIeFunction) -> Json {
  {
    "uri": @json.to_json(item.resource.uri),
    "id": optional(item.resource.id),
    "fields": {
      "ARIFunctionNumber": parity_value(item.ari_function_number),
      "BusNumber": parity_value(item.bus_number),
      "ClassCode": parity_value(item.class_code),
      "DeviceClass": parity_value(item.device_class),
      "DeviceId": parity_value(item.device_id),
      "DeviceNumber": parity_value(item.device_number),
      "FunctionNumber": parity_value(item.function_number),
      "FunctionProtocol": parity_value(item.function_protocol),
      "FunctionType": parity_value(item.function_type),
      "RevisionId": parity_value(item.revision_id),
      "SegmentNumber": parity_value(item.segment_number),
      "SubsystemId": parity_value(item.subsystem_id),
      "SubsystemVendorId": parity_value(item.subsystem_vendor_id),
      "VendorId": parity_value(item.vendor_id),
      "ARIModeEnabled": parity_value(item.ari_mode_enabled),
      "Enabled": parity_value(item.enabled),
      "FunctionId": parity_value(item.function_id),
      "Status": pcie_health(item.status),
    },
  }
}

///|
fn[T] pcie_items(
  items : @moonredfish.Field[Array[T]],
  project : (T) -> Json,
) -> Json {
  match items {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(items) =>
      { "state": "value", "value": @json.to_json(items.map(project)) }
  }
}

///|
async fn pcie(c : @moonredfish.Client) -> Json {
  guard c.get("/redfish/v1/PCIeTests").json is { "Cases": Array(cases), .. } else {
    fail("invalid PCIe manifest")
  }
  let out : Map[String, Json] = Map([])
  for probe in cases {
    guard probe
      is { "ID": String(id), "URI": String(uri), "Kind": String(kind), .. } else {
      fail("invalid PCIe case")
    }
    out[id] = try {
      let owner = c.get(uri)
      let result = match kind {
        "device" => pcie_device_json(owner.pcie_device())
        "function" => pcie_function_json(owner.pcie_function())
        "system_devices" =>
          pcie_items(c.system_pcie_devices(owner), pcie_device_json)
        "system_functions" =>
          pcie_items(c.system_pcie_functions(owner), pcie_function_json)
        "chassis_devices" =>
          pcie_items(c.chassis_pcie_devices(owner), pcie_device_json)
        "device_functions" =>
          pcie_items(c.pcie_functions(owner), pcie_function_json)
        "function_device" =>
          match c.pcie_function_device(owner) {
            Missing => { "state": "missing" }
            Null => { "state": "null" }
            Value(item) => { "state": "value", "value": pcie_device_json(item) }
          }
        _ => fail("invalid PCIe operation")
      }
      { "ok": true, "error": "", "value": result }
    } catch {
      @moonredfish.InvalidResponse(_) =>
        { "ok": false, "error": "invalid_response", "value": @json.null }
      @moonredfish.InvalidPath =>
        { "ok": false, "error": "invalid_path", "value": @json.null }
      @moonredfish.DetailedHttpStatus(_) =>
        { "ok": false, "error": "http", "value": @json.null }
      _ => fail("unexpected PCIe fixture error")
    }
  }
  { "cases": @json.to_json(out) }
}
