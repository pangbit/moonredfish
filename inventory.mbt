///|
/// A schema property distinguishes absence, explicit JSON null and a real value.
/// Unknown enum strings are retained. No measurement is replaced with zero.
pub enum Field[T] {
  Missing
  Null
  Value(T)
}

///|
/// Explicitly collapse unavailable values when the application does not need the distinction.
pub fn[T] Field::value(self : Field[T]) -> T? {
  match self {
    Value(value) => Some(value)
    Missing | Null => None
  }
}

///|
/// Reported status only; unknown strings are not classified as healthy.
pub struct Health {
  json : Json
  state : Field[String]
  health : Field[String]
  health_rollup : Field[String]
}

///|
/// Common ComputerSystem inventory fields. The original resource is retained.
pub struct SystemInfo {
  resource : Resource
  manufacturer : Field[String]
  model : Field[String]
  serial_number : Field[String]
  uuid : Field[String]
  part_number : Field[String]
  asset_tag : Field[String]
  hostname : Field[String]
  bios_version : Field[String]
  power_state : Field[String]
  status : Field[Health]
  processor_count : Field[Int32]
  total_memory_gib : Field[Double]
}

///|
/// Common Chassis inventory fields. No identifiers are redacted in memory.
pub struct ChassisInfo {
  resource : Resource
  manufacturer : Field[String]
  model : Field[String]
  serial_number : Field[String]
  uuid : Field[String]
  part_number : Field[String]
  asset_tag : Field[String]
  chassis_type : Field[String]
  power_state : Field[String]
  status : Field[Health]
}

///|
/// Common Manager inventory fields, including BMC firmware when reported.
pub struct ManagerInfo {
  resource : Resource
  manufacturer : Field[String]
  model : Field[String]
  serial_number : Field[String]
  uuid : Field[String]
  manager_type : Field[String]
  firmware_version : Field[String]
  power_state : Field[String]
  status : Field[Health]
}

///|
/// Common Processor inventory. Counts remain distinct from unknown values.
pub struct Processor {
  resource : Resource
  socket : Field[String]
  manufacturer : Field[String]
  model : Field[String]
  processor_type : Field[String]
  instruction_set : Field[String]
  architecture : Field[String]
  total_cores : Field[Int32]
  total_threads : Field[Int32]
  max_speed_mhz : Field[Double]
  status : Field[Health]
}

///|
/// Common Memory inventory. Capacity is MiB, speed is MHz, without conversion.
pub struct Memory {
  resource : Resource
  manufacturer : Field[String]
  serial_number : Field[String]
  part_number : Field[String]
  device_locator : Field[String]
  memory_device_type : Field[String]
  capacity_mib : Field[Double]
  operating_speed_mhz : Field[Double]
  status : Field[Health]
}

///|
/// One legacy Thermal temperature; signed/fractional Celsius is preserved.
pub struct Temperature {
  json : Json
  member_id : Field[String]
  name : Field[String]
  reading_celsius : Field[Double]
  upper_threshold_non_critical : Field[Double]
  upper_threshold_critical : Field[Double]
  status : Field[Health]
}

///|
/// A modern sensor excerpt; null Reading is not zero.
pub struct SensorReading {
  json : Json
  reading : Field[Double]
}

///|
/// A legacy embedded fan or modern Fan resource. Units are not guessed.
pub struct Fan {
  json : Json
  resource : Resource?
  uri : Field[String]
  id : Field[String]
  member_id : Field[String]
  name : Field[String]
  reading : Field[Double]
  reading_units : Field[String]
  speed_percent : Field[SensorReading]
  status : Field[Health]
}

///|
/// Legacy embedded supply or modern PowerSupply resource.
pub struct PowerSupply {
  json : Json
  resource : Resource?
  uri : Field[String]
  id : Field[String]
  member_id : Field[String]
  name : Field[String]
  manufacturer : Field[String]
  model : Field[String]
  serial_number : Field[String]
  part_number : Field[String]
  line_input_voltage : Field[Double]
  power_capacity_watts : Field[Double]
  last_power_output_watts : Field[Double]
  status : Field[Health]
}

///|
/// One legacy PowerControl entry. Values are reported watts, not derived.
pub struct PowerControl {
  json : Json
  member_id : Field[String]
  name : Field[String]
  power_consumed_watts : Field[Double]
  power_capacity_watts : Field[Double]
  status : Field[Health]
}

///|
/// A modern Sensor reading, with reported type and units retained as strings.
pub struct Sensor {
  resource : Resource
  reading : Field[Double]
  reading_units : Field[String]
  reading_type : Field[String]
  status : Field[Health]
}

///|
fn parse_health(value : Json) -> Health raise RedfishError {
  require_object(value)
  {
    json: value,
    state: read_field(value, "State", string_value),
    health: read_field(value, "Health", string_value),
    health_rollup: read_field(value, "HealthRollup", string_value),
  }
}

///|
pub fn Resource::system_info(self : Resource) -> SystemInfo raise RedfishError {
  let value = self.json
  {
    resource: self,
    manufacturer: read_field(value, "Manufacturer", string_value),
    model: read_field(value, "Model", string_value),
    serial_number: read_field(value, "SerialNumber", string_value),
    uuid: read_field(value, "UUID", string_value),
    part_number: read_field(value, "PartNumber", string_value),
    asset_tag: read_field(value, "AssetTag", string_value),
    hostname: read_field(value, "HostName", string_value),
    bios_version: read_field(value, "BiosVersion", string_value),
    power_state: read_field(value, "PowerState", string_value),
    status: read_field(value, "Status", parse_health),
    processor_count: nested_field(
      value, "ProcessorSummary", "Count", count_value,
    ),
    total_memory_gib: nested_field(
      value, "MemorySummary", "TotalSystemMemoryGiB", number_value,
    ),
  }
}

///|
pub fn Resource::chassis_info(
  self : Resource,
) -> ChassisInfo raise RedfishError {
  let value = self.json
  {
    resource: self,
    manufacturer: read_field(value, "Manufacturer", string_value),
    model: read_field(value, "Model", string_value),
    serial_number: read_field(value, "SerialNumber", string_value),
    uuid: read_field(value, "UUID", string_value),
    part_number: read_field(value, "PartNumber", string_value),
    asset_tag: read_field(value, "AssetTag", string_value),
    chassis_type: read_field(value, "ChassisType", string_value),
    power_state: read_field(value, "PowerState", string_value),
    status: read_field(value, "Status", parse_health),
  }
}

///|
pub fn Resource::manager_info(
  self : Resource,
) -> ManagerInfo raise RedfishError {
  let value = self.json
  {
    resource: self,
    manufacturer: read_field(value, "Manufacturer", string_value),
    model: read_field(value, "Model", string_value),
    serial_number: read_field(value, "SerialNumber", string_value),
    uuid: read_field(value, "UUID", string_value),
    manager_type: read_field(value, "ManagerType", string_value),
    firmware_version: read_field(value, "FirmwareVersion", string_value),
    power_state: read_field(value, "PowerState", string_value),
    status: read_field(value, "Status", parse_health),
  }
}

///|
pub fn Resource::processor(self : Resource) -> Processor raise RedfishError {
  let value = self.json
  {
    resource: self,
    socket: read_field(value, "Socket", string_value),
    manufacturer: read_field(value, "Manufacturer", string_value),
    model: read_field(value, "Model", string_value),
    processor_type: read_field(value, "ProcessorType", string_value),
    instruction_set: read_field(value, "InstructionSet", string_value),
    architecture: read_field(value, "ProcessorArchitecture", string_value),
    total_cores: read_field(value, "TotalCores", count_value),
    total_threads: read_field(value, "TotalThreads", count_value),
    max_speed_mhz: read_field(value, "MaxSpeedMHz", number_value),
    status: read_field(value, "Status", parse_health),
  }
}

///|
pub fn Resource::memory(self : Resource) -> Memory raise RedfishError {
  let value = self.json
  {
    resource: self,
    manufacturer: read_field(value, "Manufacturer", string_value),
    serial_number: read_field(value, "SerialNumber", string_value),
    part_number: read_field(value, "PartNumber", string_value),
    device_locator: read_field(value, "DeviceLocator", string_value),
    memory_device_type: read_field(value, "MemoryDeviceType", string_value),
    capacity_mib: read_field(value, "CapacityMiB", number_value),
    operating_speed_mhz: read_field(value, "OperatingSpeedMhz", number_value),
    status: read_field(value, "Status", parse_health),
  }
}

///|
fn parse_temperature(value : Json) -> Temperature raise RedfishError {
  require_object(value)
  {
    json: value,
    member_id: read_field(value, "MemberId", string_value),
    name: read_field(value, "Name", string_value),
    reading_celsius: read_field(value, "ReadingCelsius", number_value),
    upper_threshold_non_critical: read_field(
      value, "UpperThresholdNonCritical", number_value,
    ),
    upper_threshold_critical: read_field(
      value, "UpperThresholdCritical", number_value,
    ),
    status: read_field(value, "Status", parse_health),
  }
}

///|
fn parse_sensorreading(value : Json) -> SensorReading raise RedfishError {
  require_object(value)
  { json: value, reading: read_field(value, "Reading", number_value), }
}

///|
fn parse_fan(value : Json) -> Fan raise RedfishError {
  require_object(value)
  {
    json: value,
    resource: None,
    uri: read_field(value, "@odata.id", string_value),
    id: read_field(value, "Id", string_value),
    member_id: read_field(value, "MemberId", string_value),
    name: read_field(value, "Name", string_value),
    reading: read_field(value, "Reading", number_value),
    reading_units: read_field(value, "ReadingUnits", string_value),
    speed_percent: read_field(value, "SpeedPercent", parse_sensorreading),
    status: read_field(value, "Status", parse_health),
  }
}

///|
fn parse_powersupply(value : Json) -> PowerSupply raise RedfishError {
  require_object(value)
  {
    json: value,
    resource: None,
    uri: read_field(value, "@odata.id", string_value),
    id: read_field(value, "Id", string_value),
    member_id: read_field(value, "MemberId", string_value),
    name: read_field(value, "Name", string_value),
    manufacturer: read_field(value, "Manufacturer", string_value),
    model: read_field(value, "Model", string_value),
    serial_number: read_field(value, "SerialNumber", string_value),
    part_number: read_field(value, "PartNumber", string_value),
    line_input_voltage: read_field(value, "LineInputVoltage", number_value),
    power_capacity_watts: read_field(value, "PowerCapacityWatts", number_value),
    last_power_output_watts: read_field(
      value, "LastPowerOutputWatts", number_value,
    ),
    status: read_field(value, "Status", parse_health),
  }
}

///|
fn parse_powercontrol(value : Json) -> PowerControl raise RedfishError {
  require_object(value)
  {
    json: value,
    member_id: read_field(value, "MemberId", string_value),
    name: read_field(value, "Name", string_value),
    power_consumed_watts: read_field(value, "PowerConsumedWatts", number_value),
    power_capacity_watts: read_field(value, "PowerCapacityWatts", number_value),
    status: read_field(value, "Status", parse_health),
  }
}

///|
pub fn Resource::sensor(self : Resource) -> Sensor raise RedfishError {
  let value = self.json
  {
    resource: self,
    reading: read_field(value, "Reading", number_value),
    reading_units: read_field(value, "ReadingUnits", string_value),
    reading_type: read_field(value, "ReadingType", string_value),
    status: read_field(value, "Status", parse_health),
  }
}
