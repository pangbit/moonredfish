///|
/// Keep missing/null distinct in output. Never print hardware identifiers or raw JSON.
fn[T] count(field : @moonredfish.Field[Array[T]]) -> String {
  match field {
    Missing => "missing"
    Null => "null"
    Value(items) => items.length().to_string()
  }
}

///|
async fn inventory(client : @moonredfish.Client) -> Unit {
  for system in client.systems() {
    let info = system.system_info()
    let cores = match info.processor_count {
      Missing => "missing"
      Null => "null"
      Value(value) => value.to_string()
    }
    println(
      "system: processor_count=\{cores}, processors=\{count(client.processors(system))}, memory=\{count(client.memory(system))}",
    )
  }
  for chassis in client.chassis() {
    ignore(chassis.chassis_info())
    match client.thermal(chassis) {
      Missing => println("legacy thermal: missing")
      Null => println("legacy thermal: null")
      Value(thermal) =>
        println(
          "legacy thermal: temperatures=\{count(thermal.temperatures)}, fans=\{count(thermal.fans)}",
        )
    }
    match client.power(chassis) {
      Missing => println("legacy power: missing")
      Null => println("legacy power: null")
      Value(power) =>
        println(
          "legacy power: supplies=\{count(power.power_supplies)}, controls=\{count(power.power_control)}",
        )
    }
    println("sensors: \{count(client.sensors(chassis))}")
    match client.thermal_subsystem(chassis) {
      Missing => println("thermal subsystem: missing")
      Null => println("thermal subsystem: null")
      Value(subsystem) =>
        println("modern fans: \{count(client.fans(subsystem))}")
    }
    match client.power_subsystem(chassis) {
      Missing => println("power subsystem: missing")
      Null => println("power subsystem: null")
      Value(subsystem) =>
        println("modern supplies: \{count(client.power_supplies(subsystem))}")
    }
  }
  for manager in client.managers() {
    ignore(manager.manager_info())
  }
}

///|
async fn main {
  let args = @env.args()
  if args.length() == 1 {
    // Safe default: synthetic data only; no network or credentials.
    let thermal = @moonredfish.parse_resource(
      "/redfish/v1/Chassis/demo/Thermal",
      { "Temperatures": [{ "ReadingCelsius": 0 }], "Fans": null },
    ).thermal()
    println(
      "offline synthetic thermal: temperatures=\{count(thermal.temperatures)}, fans=\{count(thermal.fans)}",
    )
    guard thermal.temperatures is Value(temperatures) else {
      fail("missing synthetic data")
    }
    match temperatures[0].reading_celsius {
      Missing => println("temperature: missing")
      Null => println("temperature: null")
      Value(value) => println("temperature: \{value} Celsius")
    }
  } else {
    guard args.length() == 2 else {
      fail("usage: hardware [https://authorized-bmc.example.invalid]")
    }
    let ca_file = @env.get_env_var("REDFISH_CA_FILE")
    let client = @moonredfish.Client::new(args[1], ca_file?)
    match
      (
        @env.get_env_var("REDFISH_USERNAME"),
        @env.get_env_var("REDFISH_PASSWORD"),
      ) {
      (None, None) => inventory(client)
      (Some(username), Some(password)) if !username.is_empty() &&
        !password.is_empty() =>
        client.with_session(username, password, inventory)
      _ =>
        fail(
          "supply both nonempty REDFISH_USERNAME and REDFISH_PASSWORD, or neither",
        )
    }
  }
}
