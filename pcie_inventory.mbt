///|
/// Read-only PCIe inventory. Flags report state; they do not authorize actions.
pub struct PCIeDevice {
  resource : Resource
  asset_tag : Field[String]
  device_type : Field[String]
  firmware_version : Field[String]
  manufacturer : Field[String]
  model : Field[String]
  part_number : Field[String]
  sku : Field[String]
  serial_number : Field[String]
  spare_part_number : Field[String]
  staged_version : Field[String]
  uuid : Field[String]
  location_indicator_active : Field[Bool]
  ready_to_remove : Field[Bool]
  pcie_interface : Field[PCIeInterface]
  status : Field[Health]
}

///|
pub fn Resource::pcie_device(self : Resource) -> PCIeDevice raise RedfishError {
  {
    resource: self,
    asset_tag: read_field(self.json, "AssetTag", string_value),
    device_type: read_field(self.json, "DeviceType", string_value),
    firmware_version: read_field(self.json, "FirmwareVersion", string_value),
    manufacturer: read_field(self.json, "Manufacturer", string_value),
    model: read_field(self.json, "Model", string_value),
    part_number: read_field(self.json, "PartNumber", string_value),
    sku: read_field(self.json, "SKU", string_value),
    serial_number: read_field(self.json, "SerialNumber", string_value),
    spare_part_number: read_field(self.json, "SparePartNumber", string_value),
    staged_version: read_field(self.json, "StagedVersion", string_value),
    uuid: read_field(self.json, "UUID", string_value),
    location_indicator_active: read_field(
      self.json,
      "LocationIndicatorActive",
      bool_value,
    ),
    ready_to_remove: read_field(self.json, "ReadyToRemove", bool_value),
    pcie_interface: read_field(self.json, "PCIeInterface", parse_pcie_interface),
    status: read_field(self.json, "Status", parse_health),
  }
}

///|
pub struct PCIeFunction {
  resource : Resource
  ari_function_number : Field[String]
  bus_number : Field[String]
  class_code : Field[String]
  device_class : Field[String]
  device_id : Field[String]
  device_number : Field[String]
  function_number : Field[String]
  function_protocol : Field[String]
  function_type : Field[String]
  revision_id : Field[String]
  segment_number : Field[String]
  subsystem_id : Field[String]
  subsystem_vendor_id : Field[String]
  vendor_id : Field[String]
  ari_mode_enabled : Field[Bool]
  enabled : Field[Bool]
  function_id : Field[Int32]
  status : Field[Health]
}

///|
pub fn Resource::pcie_function(
  self : Resource,
) -> PCIeFunction raise RedfishError {
  {
    resource: self,
    ari_function_number: read_field(
      self.json,
      "ARIFunctionNumber",
      string_value,
    ),
    bus_number: read_field(self.json, "BusNumber", string_value),
    class_code: read_field(self.json, "ClassCode", string_value),
    device_class: read_field(self.json, "DeviceClass", string_value),
    device_id: read_field(self.json, "DeviceId", string_value),
    device_number: read_field(self.json, "DeviceNumber", string_value),
    function_number: read_field(self.json, "FunctionNumber", string_value),
    function_protocol: read_field(self.json, "FunctionProtocol", string_value),
    function_type: read_field(self.json, "FunctionType", string_value),
    revision_id: read_field(self.json, "RevisionId", string_value),
    segment_number: read_field(self.json, "SegmentNumber", string_value),
    subsystem_id: read_field(self.json, "SubsystemId", string_value),
    subsystem_vendor_id: read_field(
      self.json,
      "SubsystemVendorId",
      string_value,
    ),
    vendor_id: read_field(self.json, "VendorId", string_value),
    ari_mode_enabled: read_field(self.json, "ARIModeEnabled", bool_value),
    enabled: read_field(self.json, "Enabled", bool_value),
    function_id: read_field(self.json, "FunctionId", count_value),
    status: read_field(self.json, "Status", parse_health),
  }
}

///|
/// Lane counts retain the existing nonnegative Int32 contract. No vendor string
/// coercion, float truncation or lane-count inference is performed.
pub struct PCIeInterface {
  json : Json
  lanes_in_use : Field[Int32]
  max_lanes : Field[Int32]
  max_pcie_type : Field[String]
  pcie_type : Field[String]
}

///|
fn parse_pcie_interface(value : Json) -> PCIeInterface raise RedfishError {
  require_object(value)
  {
    json: value,
    lanes_in_use: read_field(value, "LanesInUse", count_value),
    max_lanes: read_field(value, "MaxLanes", count_value),
    max_pcie_type: read_field(value, "MaxPCIeType", string_value),
    pcie_type: read_field(value, "PCIeType", string_value),
  }
}
