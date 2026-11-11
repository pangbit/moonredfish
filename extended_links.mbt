///|
/// Follows ComputerSystem.Storage within one bounded collection operation.
pub async fn Client::storage(
  self : Client,
  owner : Resource,
) -> Field[Array[Storage]] {
  match self.linked_members(owner, "Storage") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::storage))
  }
}

///|
/// Follows Storage.Volumes within one bounded collection operation.
pub async fn Client::volumes(
  self : Client,
  owner : Resource,
) -> Field[Array[Volume]] {
  match self.linked_members(owner, "Volumes") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::volume))
  }
}

///|
/// Follows ComputerSystem or Manager.EthernetInterfaces within one bounded collection operation.
pub async fn Client::ethernet_interfaces(
  self : Client,
  owner : Resource,
) -> Field[Array[EthernetInterface]] {
  match self.linked_members(owner, "EthernetInterfaces") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::ethernet_interface))
  }
}

///|
/// Follows Chassis.NetworkAdapters within one bounded collection operation.
pub async fn Client::network_adapters(
  self : Client,
  owner : Resource,
) -> Field[Array[NetworkAdapter]] {
  match self.linked_members(owner, "NetworkAdapters") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::network_adapter))
  }
}

///|
/// Follows ComputerSystem, Chassis or Manager.LogServices within one bounded collection operation.
pub async fn Client::log_services(
  self : Client,
  owner : Resource,
) -> Field[Array[LogService]] {
  match self.linked_members(owner, "LogServices") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::log_service))
  }
}

///|
/// Follows LogService.Entries within one bounded collection operation.
pub async fn Client::log_entries(
  self : Client,
  owner : Resource,
) -> Field[Array[LogEntry]] {
  match self.linked_members(owner, "Entries") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::log_entry))
  }
}

///|
/// Follows UpdateService.FirmwareInventory within one bounded collection operation.
pub async fn Client::firmware_inventory(
  self : Client,
  owner : Resource,
) -> Field[Array[SoftwareInventory]] {
  match self.linked_members(owner, "FirmwareInventory") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::software_inventory))
  }
}

///|
/// Follows ServiceRoot.UpdateService. Firmware inventory is a separate explicit call.
pub async fn Client::update_service(
  self : Client,
  root : Resource,
) -> Field[Resource] {
  self.linked_resource(root, "UpdateService")
}

///|
/// Reads current ComputerSystem.Bios only. Does not follow SettingsObject or actions.
pub async fn Client::bios(self : Client, system : Resource) -> Field[Bios] {
  match self.linked_resource(system, "Bios") {
    Missing => Missing
    Null => Null
    Value(resource) => Value(resource.bios())
  }
}

///|
/// Follows Storage.Drives, an array of links rather than a collection.
/// Validates and deduplicates all links before GETs; shares byte/time/member limits.
pub async fn Client::drives(
  self : Client,
  storage : Resource,
) -> Field[Array[Drive]] {
  match read_array(storage.json, "Drives", link_uri) {
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
              result.push(self.read_resource(path, budget~).drive())
            }
            result
          },
          error=OperationTimeout,
        ),
      )
    }
  }
}
