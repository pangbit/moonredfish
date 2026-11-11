///|
fn pcie_link_paths(
  owner : Resource,
  key : String,
) -> Field[Array[String]] raise RedfishError {
  match read_field(owner.json, "Links", object_value) {
    Missing => Missing
    Null => Null
    Value(links) => read_array(links, key, link_uri)
  }
}

///|
/// ComputerSystem.PCIeDevices is a top-level array, not a collection link.
pub async fn Client::system_pcie_devices(
  self : Client,
  system : Resource,
) -> Field[Array[PCIeDevice]] {
  self.read_link_array(
    read_array(system.json, "PCIeDevices", link_uri),
    Resource::pcie_device,
  )
}

///|
/// ComputerSystem.PCIeFunctions is a top-level array.
pub async fn Client::system_pcie_functions(
  self : Client,
  system : Resource,
) -> Field[Array[PCIeFunction]] {
  self.read_link_array(
    read_array(system.json, "PCIeFunctions", link_uri),
    Resource::pcie_function,
  )
}

///|
/// Chassis prefers PCIeDevices collection over legacy Links.PCIeDevices.
pub async fn Client::chassis_pcie_devices(
  self : Client,
  chassis : Resource,
) -> Field[Array[PCIeDevice]] {
  let modern = read_field(chassis.json, "PCIeDevices", link_uri)
  match modern {
    Value(_) =>
      match self.linked_members(chassis, "PCIeDevices") {
        Missing => Missing
        Null => Null
        Value(items) => Value(items.map(Resource::pcie_device))
      }
    Missing | Null => {
      let paths = pcie_link_paths(chassis, "PCIeDevices")
      match paths {
        Missing =>
          match modern {
            Null => Null
            _ => Missing
          }
        _ => self.read_link_array(paths, Resource::pcie_device)
      }
    }
  }
}

///|
/// PCIeDevice prefers nonempty legacy Links.PCIeFunctions over its collection.
pub async fn Client::pcie_functions(
  self : Client,
  device : Resource,
) -> Field[Array[PCIeFunction]] {
  let legacy = pcie_link_paths(device, "PCIeFunctions")
  if legacy is Value(paths) && !paths.is_empty() {
    return self.read_link_array(legacy, Resource::pcie_function)
  }
  match self.linked_members(device, "PCIeFunctions") {
    Missing =>
      match legacy {
        Missing => Missing
        Null => Null
        Value(_) => Value([])
      }
    Null =>
      match legacy {
        Value(_) => Value([])
        _ => Null
      }
    Value(items) => Value(items.map(Resource::pcie_function))
  }
}

///|
/// Follows only PCIeFunction.Links.PCIeDevice, never recursively scans topology.
pub async fn Client::pcie_function_device(
  self : Client,
  function : Resource,
) -> Field[PCIeDevice] {
  match read_field(function.json, "Links", object_value) {
    Missing => Missing
    Null => Null
    Value(links) =>
      match
        self.linked_resource(parse_resource(function.uri, links), "PCIeDevice") {
        Missing => Missing
        Null => Null
        Value(resource) => Value(resource.pcie_device())
      }
  }
}
