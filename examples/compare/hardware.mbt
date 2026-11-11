///|
/// Test-only projection: unavailable fields are null here, not in the library API.
fn[T : @json.ToJson] field_json(field : @moonredfish.Field[T]) -> Json {
  match field {
    Value(value) => @json.to_json(value)
    Missing | Null => @json.null
  }
}

///|
fn health_json(field : @moonredfish.Field[@moonredfish.Health]) -> Json {
  match field {
    Value(status) =>
      {
        "state": field_json(status.state),
        "health": field_json(status.health),
        "health_rollup": field_json(status.health_rollup),
      }
    Missing | Null => @json.null
  }
}

///|
fn resource_record(
  resource : @moonredfish.Resource,
  status : @moonredfish.Field[@moonredfish.Health],
) -> Map[String, Json] {
  {
    "uri": @json.to_json(resource.uri),
    "id": optional(resource.id),
    "name": optional(resource.name),
    "status": health_json(status),
  }
}

///|
fn embedded_record(
  raw : Json,
  member_id : @moonredfish.Field[String],
  name : @moonredfish.Field[String],
  status : @moonredfish.Field[@moonredfish.Health],
) -> Map[String, Json] {
  let uri = match raw {
    Object(fields) => fields.get("@odata.id").unwrap_or(@json.null)
    _ => @json.null
  }
  {
    "uri": uri,
    "member_id": field_json(member_id),
    "name": field_json(name),
    "status": health_json(status),
  }
}

///|
fn[T] available_items(field : @moonredfish.Field[Array[T]]) -> Array[T] {
  field.value().unwrap_or([])
}

///|
fn hardware_system(item : @moonredfish.SystemInfo) -> Json {
  let out = resource_record(item.resource, item.status)
  out["uuid"] = field_json(item.uuid)
  out["manufacturer"] = field_json(item.manufacturer)
  out["model"] = field_json(item.model)
  out["serial_number"] = field_json(item.serial_number)
  out["part_number"] = field_json(item.part_number)
  out["asset_tag"] = field_json(item.asset_tag)
  out["bios_version"] = field_json(item.bios_version)
  out["hostname"] = field_json(item.hostname)
  out["power"] = field_json(item.power_state)
  out["processor_count"] = field_json(item.processor_count)
  out["memory_gib"] = field_json(item.total_memory_gib)
  @json.to_json(out)
}

///|
fn hardware_chassis(item : @moonredfish.ChassisInfo) -> Json {
  let out = resource_record(item.resource, item.status)
  out["uuid"] = field_json(item.uuid)
  out["manufacturer"] = field_json(item.manufacturer)
  out["model"] = field_json(item.model)
  out["serial_number"] = field_json(item.serial_number)
  out["part_number"] = field_json(item.part_number)
  out["asset_tag"] = field_json(item.asset_tag)
  out["chassis_type"] = field_json(item.chassis_type)
  out["power"] = field_json(item.power_state)
  @json.to_json(out)
}

///|
fn hardware_manager(item : @moonredfish.ManagerInfo) -> Json {
  let out = resource_record(item.resource, item.status)
  out["uuid"] = field_json(item.uuid)
  out["model"] = field_json(item.model)
  out["firmware_version"] = field_json(item.firmware_version)
  out["manager_type"] = field_json(item.manager_type)
  out["power"] = field_json(item.power_state)
  @json.to_json(out)
}

///|
fn hardware_processor(item : @moonredfish.Processor) -> Json {
  let out = resource_record(item.resource, item.status)
  out["socket"] = field_json(item.socket)
  out["architecture"] = field_json(item.architecture)
  out["manufacturer"] = field_json(item.manufacturer)
  out["model"] = field_json(item.model)
  out["processor_type"] = field_json(item.processor_type)
  out["instruction_set"] = field_json(item.instruction_set)
  out["total_cores"] = field_json(item.total_cores)
  out["total_threads"] = field_json(item.total_threads)
  out["max_speed_mhz"] = field_json(item.max_speed_mhz)
  @json.to_json(out)
}

///|
fn hardware_memory(item : @moonredfish.Memory) -> Json {
  let out = resource_record(item.resource, item.status)
  out["manufacturer"] = field_json(item.manufacturer)
  out["serial_number"] = field_json(item.serial_number)
  out["part_number"] = field_json(item.part_number)
  out["capacity_mib"] = field_json(item.capacity_mib)
  out["memory_device_type"] = field_json(item.memory_device_type)
  out["operating_speed_mhz"] = field_json(item.operating_speed_mhz)
  @json.to_json(out)
}

///|
fn hardware_temperature(item : @moonredfish.Temperature) -> Json {
  let out = embedded_record(item.json, item.member_id, item.name, item.status)
  out["reading_celsius"] = field_json(item.reading_celsius)
  out["upper_threshold_critical"] = field_json(item.upper_threshold_critical)
  @json.to_json(out)
}

///|
fn hardware_fan(item : @moonredfish.Fan) -> Json {
  let out = embedded_record(item.json, item.member_id, item.name, item.status)
  out["reading"] = field_json(item.reading)
  out["reading_units"] = field_json(item.reading_units)
  @json.to_json(out)
}

///|
fn hardware_supply(item : @moonredfish.PowerSupply) -> Json {
  let out = embedded_record(item.json, item.member_id, item.name, item.status)
  out["manufacturer"] = field_json(item.manufacturer)
  out["model"] = field_json(item.model)
  out["serial_number"] = field_json(item.serial_number)
  out["part_number"] = field_json(item.part_number)
  out["power_capacity_watts"] = field_json(item.power_capacity_watts)
  out["line_input_voltage"] = field_json(item.line_input_voltage)
  @json.to_json(out)
}

///|
fn hardware_control(item : @moonredfish.PowerControl) -> Json {
  let out = embedded_record(item.json, item.member_id, item.name, item.status)
  out["power_consumed_watts"] = field_json(item.power_consumed_watts)
  out["power_capacity_watts"] = field_json(item.power_capacity_watts)
  @json.to_json(out)
}

///|
fn hardware_sensor(item : @moonredfish.Sensor) -> Json {
  let out = resource_record(item.resource, item.status)
  out["reading"] = field_json(item.reading)
  out["reading_units"] = field_json(item.reading_units)
  out["reading_type"] = field_json(item.reading_type)
  @json.to_json(out)
}

///|
fn hardware_modern_fan(item : @moonredfish.Fan) -> Json {
  let speed = match item.speed_percent {
    Value(speed) => field_json(speed.reading)
    Missing | Null => @json.null
  }
  {
    "uri": field_json(item.uri),
    "id": field_json(item.id),
    "name": field_json(item.name),
    "speed_percent": speed,
    "status": health_json(item.status),
  }
}

///|
fn hardware_modern_supply(item : @moonredfish.PowerSupply) -> Json {
  {
    "uri": field_json(item.uri),
    "id": field_json(item.id),
    "name": field_json(item.name),
    "manufacturer": field_json(item.manufacturer),
    "model": field_json(item.model),
    "serial_number": field_json(item.serial_number),
    "part_number": field_json(item.part_number),
    "power_capacity_watts": field_json(item.power_capacity_watts),
    "status": health_json(item.status),
  }
}

///|
async fn hardware(c : @moonredfish.Client) -> Json {
  let systems : Array[Json] = []
  let chassis : Array[Json] = []
  let managers : Array[Json] = []
  let processors : Array[Json] = []
  let memory : Array[Json] = []
  let temperatures : Array[Json] = []
  let fans : Array[Json] = []
  let supplies : Array[Json] = []
  let controls : Array[Json] = []
  let sensors : Array[Json] = []
  let thermal_fans : Array[Json] = []
  let modern_supplies : Array[Json] = []
  for system in c.systems() {
    systems.push(hardware_system(system.system_info()))
    for item in available_items(c.processors(system)) {
      processors.push(hardware_processor(item))
    }
    for item in available_items(c.memory(system)) {
      memory.push(hardware_memory(item))
    }
  }
  for ch in c.chassis() {
    chassis.push(hardware_chassis(ch.chassis_info()))
    let thermal = c.thermal(ch)
    let power = c.power(ch)
    if thermal is Value(t) {
      for item in available_items(t.temperatures) {
        temperatures.push(hardware_temperature(item))
      }
      for item in available_items(t.fans) {
        fans.push(hardware_fan(item))
      }
    }
    if power is Value(p) {
      for item in available_items(p.power_supplies) {
        supplies.push(hardware_supply(item))
      }
      for item in available_items(p.power_control) {
        controls.push(hardware_control(item))
      }
    }
    // Only the synthetic modern graph omits both legacy links in this comparison.
    // Production callers may explicitly follow both families when advertised.
    if thermal.value() is None && power.value() is None {
      for item in available_items(c.sensors(ch)) {
        sensors.push(hardware_sensor(item))
      }
      if c.thermal_subsystem(ch) is Value(subsystem) {
        for item in available_items(c.fans(subsystem)) {
          thermal_fans.push(hardware_modern_fan(item))
        }
      }
      if c.power_subsystem(ch) is Value(subsystem) {
        for item in available_items(c.power_supplies(subsystem)) {
          modern_supplies.push(hardware_modern_supply(item))
        }
      }
    }
  }
  for manager in c.managers() {
    managers.push(hardware_manager(manager.manager_info()))
  }
  {
    "systems": @json.to_json(systems),
    "chassis": @json.to_json(chassis),
    "managers": @json.to_json(managers),
    "processors": @json.to_json(processors),
    "memory": @json.to_json(memory),
    "temperatures": @json.to_json(temperatures),
    "fans": @json.to_json(fans),
    "power_supplies": @json.to_json(supplies),
    "power_control": @json.to_json(controls),
    "sensors": @json.to_json(sensors),
    "thermal_fans": @json.to_json(thermal_fans),
    "modern_power_supplies": @json.to_json(modern_supplies),
  }
}
