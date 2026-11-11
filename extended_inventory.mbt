///|
/// Storage resource; drives and volumes are read explicitly, never recursively.
pub struct Storage {
  resource : Resource
  status : Field[Health]
}

///|
pub fn Resource::storage(self : Resource) -> Storage raise RedfishError {
  { resource: self, status: read_field(self.json, "Status", parse_health), }
}

///|
/// Selected physical drive inventory, without conflating it with a volume.
pub struct Drive {
  resource : Resource
  manufacturer : Field[String]
  model : Field[String]
  serial_number : Field[String]
  part_number : Field[String]
  revision : Field[String]
  protocol : Field[String]
  media_type : Field[String]
  capacity_bytes : Field[Double]
  failure_predicted : Field[Bool]
  status : Field[Health]
}

///|
pub fn Resource::drive(self : Resource) -> Drive raise RedfishError {
  {
    resource: self,
    manufacturer: read_field(self.json, "Manufacturer", string_value),
    model: read_field(self.json, "Model", string_value),
    serial_number: read_field(self.json, "SerialNumber", string_value),
    part_number: read_field(self.json, "PartNumber", string_value),
    revision: read_field(self.json, "Revision", string_value),
    protocol: read_field(self.json, "Protocol", string_value),
    media_type: read_field(self.json, "MediaType", string_value),
    capacity_bytes: read_field(self.json, "CapacityBytes", safe_integer_value),
    failure_predicted: read_field(self.json, "FailurePredicted", bool_value),
    status: read_field(self.json, "Status", parse_health),
  }
}

///|
/// Selected logical volume inventory. RAIDType and VolumeType remain separate.
pub struct Volume {
  resource : Resource
  capacity_bytes : Field[Double]
  volume_type : Field[String]
  raid_type : Field[String]
  status : Field[Health]
}

///|
pub fn Resource::volume(self : Resource) -> Volume raise RedfishError {
  {
    resource: self,
    capacity_bytes: read_field(self.json, "CapacityBytes", safe_integer_value),
    volume_type: read_field(self.json, "VolumeType", string_value),
    raid_type: read_field(self.json, "RAIDType", string_value),
    status: read_field(self.json, "Status", parse_health),
  }
}

///|
/// Interface inventory. MAC addresses and hostname remain private caller data.
pub struct EthernetInterface {
  resource : Resource
  mac_address : Field[String]
  permanent_mac_address : Field[String]
  hostname : Field[String]
  fqdn : Field[String]
  interface_enabled : Field[Bool]
  speed_mbps : Field[Double]
  full_duplex : Field[Bool]
  link_status : Field[String]
  status : Field[Health]
}

///|
pub fn Resource::ethernet_interface(
  self : Resource,
) -> EthernetInterface raise RedfishError {
  {
    resource: self,
    mac_address: read_field(self.json, "MACAddress", string_value),
    permanent_mac_address: read_field(
      self.json,
      "PermanentMACAddress",
      string_value,
    ),
    hostname: read_field(self.json, "HostName", string_value),
    fqdn: read_field(self.json, "FQDN", string_value),
    interface_enabled: read_field(self.json, "InterfaceEnabled", bool_value),
    speed_mbps: read_field(self.json, "SpeedMbps", safe_integer_value),
    full_duplex: read_field(self.json, "FullDuplex", bool_value),
    link_status: read_field(self.json, "LinkStatus", string_value),
    status: read_field(self.json, "Status", parse_health),
  }
}

///|
/// Physical network adapter inventory, separate from EthernetInterface.
pub struct NetworkAdapter {
  resource : Resource
  manufacturer : Field[String]
  model : Field[String]
  serial_number : Field[String]
  part_number : Field[String]
  status : Field[Health]
}

///|
pub fn Resource::network_adapter(
  self : Resource,
) -> NetworkAdapter raise RedfishError {
  {
    resource: self,
    manufacturer: read_field(self.json, "Manufacturer", string_value),
    model: read_field(self.json, "Model", string_value),
    serial_number: read_field(self.json, "SerialNumber", string_value),
    part_number: read_field(self.json, "PartNumber", string_value),
    status: read_field(self.json, "Status", parse_health),
  }
}

///|
/// Read-only log service metadata. No clear-log or log-control API exists.
pub struct LogService {
  resource : Resource
  date_time : Field[String]
  service_enabled : Field[Bool]
  max_number_of_records : Field[Double]
  over_write_policy : Field[String]
  status : Field[Health]
}

///|
pub fn Resource::log_service(self : Resource) -> LogService raise RedfishError {
  {
    resource: self,
    date_time: read_field(self.json, "DateTime", string_value),
    service_enabled: read_field(self.json, "ServiceEnabled", bool_value),
    max_number_of_records: read_field(
      self.json,
      "MaxNumberOfRecords",
      safe_integer_value,
    ),
    over_write_policy: read_field(self.json, "OverWritePolicy", string_value),
    status: read_field(self.json, "Status", parse_health),
  }
}

///|
/// Log text and message arguments can contain private data. Never print by default.
pub struct LogEntry {
  resource : Resource
  entry_type : Field[String]
  severity : Field[String]
  created : Field[String]
  message : Field[String]
  message_id : Field[String]
  message_args : Field[Array[String]]
}

///|
pub fn Resource::log_entry(self : Resource) -> LogEntry raise RedfishError {
  {
    resource: self,
    entry_type: read_field(self.json, "EntryType", string_value),
    severity: read_field(self.json, "Severity", string_value),
    created: read_field(self.json, "Created", string_value),
    message: read_field(self.json, "Message", string_value),
    message_id: read_field(self.json, "MessageId", string_value),
    message_args: read_array(self.json, "MessageArgs", string_value),
  }
}

///|
/// Firmware inventory only. Updateable is a reported capability, not permission.
pub struct SoftwareInventory {
  resource : Resource
  version : Field[String]
  software_id : Field[String]
  manufacturer : Field[String]
  lowest_supported_version : Field[String]
  updateable : Field[Bool]
  status : Field[Health]
}

///|
pub fn Resource::software_inventory(
  self : Resource,
) -> SoftwareInventory raise RedfishError {
  {
    resource: self,
    version: read_field(self.json, "Version", string_value),
    software_id: read_field(self.json, "SoftwareId", string_value),
    manufacturer: read_field(self.json, "Manufacturer", string_value),
    lowest_supported_version: read_field(
      self.json,
      "LowestSupportedVersion",
      string_value,
    ),
    updateable: read_field(self.json, "Updateable", bool_value),
    status: read_field(self.json, "Status", parse_health),
  }
}

///|
/// Current BIOS attributes retained as an object; no settings write or action.
pub struct Bios {
  resource : Resource
  attribute_registry : Field[String]
  attributes : Field[Json]
}

///|
pub fn Resource::bios(self : Resource) -> Bios raise RedfishError {
  {
    resource: self,
    attribute_registry: read_field(self.json, "AttributeRegistry", string_value),
    attributes: read_field(self.json, "Attributes", object_value),
  }
}
