///|
test "typed system preserves missing null zero and unknown health" {
  let raw : Json = {
    "Manufacturer": null,
    "UUID": "synthetic-uuid",
    "PowerState": "FuturePowerState",
    "ProcessorSummary": { "Count": 0 },
    "MemorySummary": { "TotalSystemMemoryGiB": 0.0 },
    "Status": { "State": "Enabled", "Health": "FutureHealth" },
    "Oem": { "Example": true },
  }
  let s = @moonredfish.parse_resource("/redfish/v1/Systems/demo", raw).system_info()
  assert_true(s.manufacturer is Null)
  assert_true(s.model is Missing)
  assert_true(s.processor_count is Value(0))
  assert_true(s.total_memory_gib is Value(0.0))
  assert_eq(s.uuid.value(), Some("synthetic-uuid"))
  assert_eq(s.power_state.value(), Some("FuturePowerState"))
  guard s.status is Value(status) else { fail("missing status") }
  assert_eq(status.health.value(), Some("FutureHealth"))
  assert_true(status.health_rollup is Missing)
  assert_eq(s.resource.json, raw)
}

///|
test "typed inventory never turns malformed fields into missing fields" {
  let values : Array[Json] = [
    { "Model": 2 },
    { "Status": false },
    { "Status": { "Health": [] } },
    { "ProcessorSummary": [] },
    { "ProcessorSummary": { "Count": -1 } },
    { "ProcessorSummary": { "Count": 1.5 } },
    { "ProcessorSummary": { "Count": 2147483648.0 } },
    { "MemorySummary": { "TotalSystemMemoryGiB": "32" } },
  ]
  for value in values {
    let rejected = try {
      ignore(
        @moonredfish.parse_resource("/redfish/v1/Systems/demo", value).system_info(),
      )
      false
    } catch {
      @moonredfish.InvalidResponse(_) => true
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "summary parents retain unavailable distinction" {
  let missing = @moonredfish.parse_resource("/redfish/v1/Systems/demo", {}).system_info()
  let null = @moonredfish.parse_resource("/redfish/v1/Systems/demo", {
    "ProcessorSummary": null,
    "MemorySummary": { "TotalSystemMemoryGiB": null },
    "Status": null,
  }).system_info()
  assert_true(missing.processor_count is Missing)
  assert_true(null.processor_count is Null)
  assert_true(null.total_memory_gib is Null)
  assert_true(null.status is Null)
}

///|
test "chassis manager processor and memory typed fields" {
  let r = @moonredfish.parse_resource("/redfish/v1/Systems/demo", {
    "Manufacturer": "Synthetic",
    "Model": "Demo",
    "SerialNumber": "SYNTHETIC-001",
    "PartNumber": "SYNTHETIC-PART",
    "FirmwareVersion": "test",
    "BiosVersion": "test",
    "Socket": "CPU1",
    "ProcessorArchitecture": "x86",
    "TotalCores": 8,
    "TotalThreads": 16,
    "MaxSpeedMHz": 3200,
    "CapacityMiB": 16384,
    "OperatingSpeedMhz": 2400,
    "DeviceLocator": "DIMM1",
    "MemoryDeviceType": "FutureMemory",
    "Status": {},
  })
  assert_eq(r.chassis_info().serial_number.value(), Some("SYNTHETIC-001"))
  assert_eq(r.manager_info().firmware_version.value(), Some("test"))
  assert_eq(r.processor().total_threads.value(), Some(16))
  assert_eq(r.processor().max_speed_mhz.value(), Some(3200.0))
  assert_eq(r.memory().capacity_mib.value(), Some(16384.0))
  assert_eq(r.memory().operating_speed_mhz.value(), Some(2400.0))
  assert_eq(r.memory().memory_device_type.value(), Some("FutureMemory"))
  assert_true(r.processor().status is Value(_))
}

///|
test "thermal preserves unavailable arrays zero RPM and fractional Celsius" {
  let absent = @moonredfish.parse_resource("/redfish/v1/Chassis/demo/Thermal", {}).thermal()
  assert_true(absent.temperatures is Missing)
  let raw : Json = {
    "Temperatures": [{ "MemberId": "0", "ReadingCelsius": -0.5 }],
    "Fans": [
      {
        "MemberId": "0",
        "Reading": 0,
        "ReadingUnits": "RPM",
        "Status": { "State": "Absent" },
      },
      { "MemberId": "1", "Reading": null, "ReadingUnits": "Percent" },
    ],
  }
  let thermal = @moonredfish.parse_resource(
    "/redfish/v1/Chassis/demo/Thermal", raw,
  ).thermal()
  guard thermal.temperatures is Value(temperatures) else {
    fail("missing temperatures")
  }
  guard thermal.fans is Value(fans) else { fail("missing fans") }
  assert_eq(temperatures[0].reading_celsius.value(), Some(-0.5))
  assert_eq(fans[0].reading.value(), Some(0.0))
  assert_eq(fans[0].reading_units.value(), Some("RPM"))
  assert_true(fans[1].reading is Null)
  assert_true(fans[0].speed_percent is Missing)
  assert_eq(thermal.resource.json, raw)
  let empty = @moonredfish.parse_resource("/redfish/v1/Chassis/demo/Thermal", {
    "Temperatures": null,
    "Fans": [],
  }).thermal()
  assert_true(empty.temperatures is Null)
  guard empty.fans is Value(fans) else { fail("missing fans") }
  assert_eq(fans.length(), 0)
}

///|
test "power and modern sensors keep raw JSON and reported units" {
  let power = @moonredfish.parse_resource("/redfish/v1/Chassis/demo/Power", {
    "PowerSupplies": [
      { "MemberId": "0", "PowerCapacityWatts": 750, "LastPowerOutputWatts": 0 },
    ],
    "PowerControl": [{ "PowerConsumedWatts": null }],
  }).power()
  guard power.power_supplies is Value(supplies) else {
    fail("missing supplies")
  }
  assert_eq(supplies[0].power_capacity_watts.value(), Some(750.0))
  assert_eq(supplies[0].last_power_output_watts.value(), Some(0.0))
  guard power.power_control is Value(control) else { fail("missing control") }
  assert_true(control[0].power_consumed_watts is Null)
  let raw : Json = {
    "Reading": 0,
    "ReadingUnits": "Cel",
    "ReadingType": "FutureType",
    "Oem": { "Example": true },
  }
  let sensor = @moonredfish.parse_resource(
    "/redfish/v1/Chassis/demo/Sensors/0", raw,
  ).sensor()
  assert_eq(sensor.reading.value(), Some(0.0))
  assert_eq(sensor.reading_units.value(), Some("Cel"))
  assert_eq(sensor.reading_type.value(), Some("FutureType"))
  assert_eq(sensor.resource.json, raw)
  let fan = @moonredfish.parse_resource(
    "/redfish/v1/Chassis/demo/ThermalSubsystem/Fans/0",
    { "SpeedPercent": { "Reading": 0 } },
  ).fan()
  guard fan.speed_percent is Value(speed) else { fail("missing speed") }
  assert_eq(speed.reading.value(), Some(0.0))
  assert_true(fan.reading is Missing)
  assert_eq(
    fan.resource.unwrap().uri,
    "/redfish/v1/Chassis/demo/ThermalSubsystem/Fans/0",
  )
  assert_true(fan.uri is Missing)
}

///|
test "malformed embedded arrays and readings fail closed" {
  let values : Array[Json] = [
    { "Temperatures": {} },
    { "Fans": [null] },
    { "Fans": [{ "Reading": "0" }] },
    { "Fans": [{ "SpeedPercent": 0 }] },
    { "Fans": [{ "Status": { "State": 1 } }] },
  ]
  for raw in values {
    assert_true(
      try {
        ignore(
          @moonredfish.parse_resource("/redfish/v1/Chassis/demo/Thermal", raw).thermal(),
        )
        false
      } catch {
        @moonredfish.InvalidResponse(_) => true
        _ => false
      },
    )
  }
}
