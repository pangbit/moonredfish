///|
fn main raise {
  let system = @moonredfish.parse_resource("/redfish/v1/Systems/demo", {
    "Id": "demo",
    "Name": "Synthetic server",
    "PowerState": "On",
  })
  println(
    "\{system.id.unwrap_or("unknown")}: \{system.name.unwrap_or("unnamed")} (power: \{system.string("PowerState").unwrap_or("unknown")})",
  )
}
