///|
/// Follows ComputerSystem.Boot.BootOptions as one bounded collection read.
pub async fn Client::boot_options(
  self : Client,
  system : Resource,
) -> Field[Array[BootOption]] {
  match read_field(system.json, "Boot", object_value) {
    Missing => Missing
    Null => Null
    Value(boot) =>
      match
        self.linked_members(parse_resource(system.uri, boot), "BootOptions") {
        Missing => Missing
        Null => Null
        Value(items) => Value(items.map(Resource::boot_option))
      }
  }
}

///|
/// Reads the explicit ComputerSystem.SecureBoot link; no configuration is applied.
pub async fn Client::secure_boot(
  self : Client,
  system : Resource,
) -> Field[SecureBoot] {
  match self.linked_resource(system, "SecureBoot") {
    Missing => Missing
    Null => Null
    Value(resource) => Value(resource.secure_boot())
  }
}

///|
/// Follows SecureBoot.SecureBootDatabases without enumerating their contents.
pub async fn Client::secure_boot_databases(
  self : Client,
  boot : Resource,
) -> Field[Array[SecureBootDatabase]] {
  match self.linked_members(boot, "SecureBootDatabases") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::secure_boot_database))
  }
}

///|
/// Reads SecureBootDatabase.Signatures; signature strings are not printed or interpreted.
pub async fn Client::signatures(
  self : Client,
  database : Resource,
) -> Field[Array[Signature]] {
  match self.linked_members(database, "Signatures") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::signature))
  }
}
