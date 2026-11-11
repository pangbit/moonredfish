///|
fn extended_storage(item : @moonredfish.Storage) -> Json {
  let out = resource_record(item.resource, item.status)
  @json.to_json(out)
}

///|
fn extended_drive(item : @moonredfish.Drive) -> Json {
  let out = resource_record(item.resource, item.status)
  out["manufacturer"] = field_json(item.manufacturer)
  out["model"] = field_json(item.model)
  out["serial_number"] = field_json(item.serial_number)
  out["part_number"] = field_json(item.part_number)
  out["revision"] = field_json(item.revision)
  out["protocol"] = field_json(item.protocol)
  out["media_type"] = field_json(item.media_type)
  out["capacity_bytes"] = field_json(item.capacity_bytes)
  out["failure_predicted"] = field_json(item.failure_predicted)
  @json.to_json(out)
}

///|
fn extended_volume(item : @moonredfish.Volume) -> Json {
  let out = resource_record(item.resource, item.status)
  out["capacity_bytes"] = field_json(item.capacity_bytes)
  out["volume_type"] = field_json(item.volume_type)
  out["raid_type"] = field_json(item.raid_type)
  @json.to_json(out)
}

///|
fn extended_ethernet_interface(item : @moonredfish.EthernetInterface) -> Json {
  let out = resource_record(item.resource, item.status)
  out["mac_address"] = field_json(item.mac_address)
  out["permanent_mac_address"] = field_json(item.permanent_mac_address)
  out["hostname"] = field_json(item.hostname)
  out["fqdn"] = field_json(item.fqdn)
  out["interface_enabled"] = field_json(item.interface_enabled)
  out["speed_mbps"] = field_json(item.speed_mbps)
  out["full_duplex"] = field_json(item.full_duplex)
  out["link_status"] = field_json(item.link_status)
  @json.to_json(out)
}

///|
fn extended_network_adapter(item : @moonredfish.NetworkAdapter) -> Json {
  let out = resource_record(item.resource, item.status)
  out["manufacturer"] = field_json(item.manufacturer)
  out["model"] = field_json(item.model)
  out["serial_number"] = field_json(item.serial_number)
  out["part_number"] = field_json(item.part_number)
  @json.to_json(out)
}

///|
fn extended_log_service(item : @moonredfish.LogService) -> Json {
  let out = resource_record(item.resource, item.status)
  out["date_time"] = field_json(item.date_time)
  out["service_enabled"] = field_json(item.service_enabled)
  out["max_number_of_records"] = field_json(item.max_number_of_records)
  out["over_write_policy"] = field_json(item.over_write_policy)
  @json.to_json(out)
}

///|
fn extended_log_entry(item : @moonredfish.LogEntry) -> Json {
  let out : Map[String, Json] = {
    "uri": @json.to_json(item.resource.uri),
    "id": optional(item.resource.id),
    "name": optional(item.resource.name),
  }
  out["entry_type"] = field_json(item.entry_type)
  out["severity"] = field_json(item.severity)
  out["created"] = field_json(item.created)
  out["message"] = field_json(item.message)
  out["message_id"] = field_json(item.message_id)
  out["message_args"] = field_json(item.message_args)
  @json.to_json(out)
}

///|
fn extended_software_inventory(item : @moonredfish.SoftwareInventory) -> Json {
  let out = resource_record(item.resource, item.status)
  out["version"] = field_json(item.version)
  out["software_id"] = field_json(item.software_id)
  out["manufacturer"] = field_json(item.manufacturer)
  out["lowest_supported_version"] = field_json(item.lowest_supported_version)
  out["updateable"] = field_json(item.updateable)
  @json.to_json(out)
}

///|
fn extended_bios(item : @moonredfish.Bios) -> Json {
  let out : Map[String, Json] = {
    "uri": @json.to_json(item.resource.uri),
    "id": optional(item.resource.id),
    "name": optional(item.resource.name),
  }
  out["attribute_registry"] = field_json(item.attribute_registry)
  out["attributes"] = field_json(item.attributes)
  @json.to_json(out)
}

///|
async fn extended(c : @moonredfish.Client) -> Json {
  let storage : Array[Json] = []
  let drives : Array[Json] = []
  let volumes : Array[Json] = []
  let ethernet_interfaces : Array[Json] = []
  let network_adapters : Array[Json] = []
  let log_services : Array[Json] = []
  let log_entries : Array[Json] = []
  let firmware_inventory : Array[Json] = []
  let bios : Array[Json] = []
  for system in c.systems() {
    for s in available_items(c.storage(system)) {
      storage.push(extended_storage(s))
      for d in available_items(c.drives(s.resource)) {
        drives.push(extended_drive(d))
      }
      for v in available_items(c.volumes(s.resource)) {
        volumes.push(extended_volume(v))
      }
    }
    for n in available_items(c.ethernet_interfaces(system)) {
      ethernet_interfaces.push(extended_ethernet_interface(n))
    }
    if c.bios(system) is Value(b) {
      bios.push(extended_bios(b))
    }
    extended_logs(c, system, log_services, log_entries)
  }
  for manager in c.managers() {
    for n in available_items(c.ethernet_interfaces(manager)) {
      ethernet_interfaces.push(extended_ethernet_interface(n))
    }
    extended_logs(c, manager, log_services, log_entries)
  }
  for chassis in c.chassis() {
    for n in available_items(c.network_adapters(chassis)) {
      network_adapters.push(extended_network_adapter(n))
    }
    extended_logs(c, chassis, log_services, log_entries)
  }
  if c.update_service(c.service_root()) is Value(update) {
    for f in available_items(c.firmware_inventory(update)) {
      firmware_inventory.push(extended_software_inventory(f))
    }
  }
  {
    "storage": @json.to_json(storage),
    "drives": @json.to_json(drives),
    "volumes": @json.to_json(volumes),
    "ethernet_interfaces": @json.to_json(ethernet_interfaces),
    "network_adapters": @json.to_json(network_adapters),
    "log_services": @json.to_json(log_services),
    "log_entries": @json.to_json(log_entries),
    "firmware_inventory": @json.to_json(firmware_inventory),
    "bios": @json.to_json(bios),
  }
}

///|
async fn extended_logs(
  c : @moonredfish.Client,
  owner : @moonredfish.Resource,
  services : Array[Json],
  entries : Array[Json],
) -> Unit {
  for log in available_items(c.log_services(owner)) {
    services.push(extended_log_service(log))
    for entry in available_items(c.log_entries(log.resource)) {
      entries.push(extended_log_entry(entry))
    }
  }
}
