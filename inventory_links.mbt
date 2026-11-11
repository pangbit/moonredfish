///|
/// Legacy chassis Thermal arrays. Missing/null arrays differ from empty arrays.
pub struct Thermal {
  resource : Resource
  temperatures : Field[Array[Temperature]]
  fans : Field[Array[Fan]]
}

///|
/// Legacy chassis Power arrays, without inventing aggregate health or totals.
pub struct Power {
  resource : Resource
  power_supplies : Field[Array[PowerSupply]]
  power_control : Field[Array[PowerControl]]
}

///|
pub fn Resource::thermal(self : Resource) -> Thermal raise RedfishError {
  {
    resource: self,
    temperatures: read_array(self.json, "Temperatures", parse_temperature),
    fans: read_array(self.json, "Fans", parse_fan),
  }
}

///|
pub fn Resource::power(self : Resource) -> Power raise RedfishError {
  {
    resource: self,
    power_supplies: read_array(self.json, "PowerSupplies", parse_powersupply),
    power_control: read_array(self.json, "PowerControl", parse_powercontrol),
  }
}

///|
pub fn Resource::fan(self : Resource) -> Fan raise RedfishError {
  let fan = parse_fan(self.json)
  { ..fan, resource: Some(self), }
}

///|
pub fn Resource::power_supply(
  self : Resource,
) -> PowerSupply raise RedfishError {
  let supply = parse_powersupply(self.json)
  { ..supply, resource: Some(self), }
}

///|
/// Fetches a linked collection within one shared body/member/page/time budget.
/// Missing/null links are not errors; advertised links returning 403/404 are errors.
async fn Client::linked_members(
  self : Client,
  owner : Resource,
  key : String,
) -> Field[Array[Resource]] {
  match read_field(owner.json, key, link_uri) {
    Missing => Missing
    Null => Null
    Value(path) => {
      let budget = ReadBudget::{ remaining: self.max_total_response_bytes, }
      Value(
        @async.with_timeout(
          self.operation_timeout_ms,
          async fn() {
            let result = []
            for uri in self.read_members(path, budget) {
              result.push(self.read_resource(uri, budget~))
            }
            result
          },
          error=OperationTimeout,
        ),
      )
    }
  }
}

///|
async fn Client::linked_resource(
  self : Client,
  owner : Resource,
  key : String,
) -> Field[Resource] {
  match read_field(owner.json, key, link_uri) {
    Missing => Missing
    Null => Null
    Value(path) => {
      let budget = ReadBudget::{ remaining: self.max_total_response_bytes, }
      Value(
        @async.with_timeout(
          self.operation_timeout_ms,
          async fn() { self.read_resource(path, budget~) },
          error=OperationTimeout,
        ),
      )
    }
  }
}

///|
/// Follows ComputerSystem.Processors. Does not guess a conventional URI.
pub async fn Client::processors(
  self : Client,
  system : Resource,
) -> Field[Array[Processor]] {
  match self.linked_members(system, "Processors") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::processor))
  }
}

///|
/// Follows ComputerSystem.Memory; incomplete collections are never returned.
pub async fn Client::memory(
  self : Client,
  system : Resource,
) -> Field[Array[Memory]] {
  match self.linked_members(system, "Memory") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::memory))
  }
}

///|
/// Follows the legacy Chassis.Thermal link; no fallback to newer resources.
pub async fn Client::thermal(
  self : Client,
  chassis : Resource,
) -> Field[Thermal] {
  match self.linked_resource(chassis, "Thermal") {
    Missing => Missing
    Null => Null
    Value(resource) => Value(resource.thermal())
  }
}

///|
/// Follows the legacy Chassis.Power link; no fallback to newer resources.
pub async fn Client::power(self : Client, chassis : Resource) -> Field[Power] {
  match self.linked_resource(chassis, "Power") {
    Missing => Missing
    Null => Null
    Value(resource) => Value(resource.power())
  }
}

///|
/// Follows a Chassis Sensors collection. Units and ReadingType are preserved.
pub async fn Client::sensors(
  self : Client,
  owner : Resource,
) -> Field[Array[Sensor]] {
  match self.linked_members(owner, "Sensors") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::sensor))
  }
}

///|
/// Discovers a modern subsystem. Call fans on the returned resource if present.
pub async fn Client::thermal_subsystem(
  self : Client,
  chassis : Resource,
) -> Field[Resource] {
  self.linked_resource(chassis, "ThermalSubsystem")
}

///|
/// Discovers a modern subsystem. Call power_supplies on the returned resource if present.
pub async fn Client::power_subsystem(
  self : Client,
  chassis : Resource,
) -> Field[Resource] {
  self.linked_resource(chassis, "PowerSubsystem")
}

///|
/// Follows ThermalSubsystem.Fans. Modern SpeedPercent is separate from legacy Reading.
pub async fn Client::fans(
  self : Client,
  subsystem : Resource,
) -> Field[Array[Fan]] {
  match self.linked_members(subsystem, "Fans") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::fan))
  }
}

///|
/// Follows PowerSubsystem.PowerSupplies. Metrics links remain in the raw JSON.
pub async fn Client::power_supplies(
  self : Client,
  subsystem : Resource,
) -> Field[Array[PowerSupply]] {
  match self.linked_members(subsystem, "PowerSupplies") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::power_supply))
  }
}

///|
/// Validated link arrays share member/byte/time limits and first-occurrence order.
async fn[T] Client::read_link_array(
  self : Client,
  paths : Field[Array[String]],
  decode : (Resource) -> T raise RedfishError,
) -> Field[Array[T]] {
  match paths {
    Missing => Missing
    Null => Null
    Value(paths) => {
      let seen : Map[String, Bool] = Map([])
      let unique = []
      for path in paths {
        if !seen.contains(path) {
          if unique.length() >= self.max_members {
            raise MemberLimit
          }
          seen[path] = true
          unique.push(path)
        }
      }
      let budget = ReadBudget::{ remaining: self.max_total_response_bytes, }
      Value(
        @async.with_timeout(
          self.operation_timeout_ms,
          async fn() {
            let result = []
            for path in unique {
              result.push(decode(self.read_resource(path, budget~)))
            }
            result
          },
          error=OperationTimeout,
        ),
      )
    }
  }
}
