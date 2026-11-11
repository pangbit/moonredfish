///|
/// Follows ServiceRoot.CertificateService without invoking certificate actions.
pub async fn Client::certificate_service(
  self : Client,
  root : Resource,
) -> Field[Resource] {
  self.linked_resource(root, "CertificateService")
}

///|
/// Follows CertificateService.CertificateLocations as a singleton resource.
pub async fn Client::certificate_locations(
  self : Client,
  service : Resource,
) -> Field[Resource] {
  self.linked_resource(service, "CertificateLocations")
}

///|
/// Reads an owner's explicit Certificates collection, including System and SecureBootDatabase.
pub async fn Client::certificates(
  self : Client,
  owner : Resource,
) -> Field[Array[Certificate]] {
  match self.linked_members(owner, "Certificates") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::certificate))
  }
}

///|
/// Reads ComputerSystem.Boot.Certificates; it does not use top-level Certificates.
pub async fn Client::boot_certificates(
  self : Client,
  system : Resource,
) -> Field[Array[Certificate]] {
  match read_field(system.json, "Boot", object_value) {
    Missing => Missing
    Null => Null
    Value(boot) => self.certificates(parse_resource(system.uri, boot))
  }
}

///|
fn certificate_link_paths(
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
/// Reads CertificateLocations.Links.Certificates; each result retains its URI and raw JSON.
pub async fn Client::certificate_location_certificates(
  self : Client,
  locations : Resource,
) -> Field[Array[Certificate]] {
  self.read_link_array(
    certificate_link_paths(locations, "Certificates"),
    Resource::certificate,
  )
}

///|
/// Reads Certificate.Links.Subjects once, without recursively walking a certificate chain.
pub async fn Client::certificate_subjects(
  self : Client,
  certificate : Resource,
) -> Field[Array[Certificate]] {
  self.read_link_array(
    certificate_link_paths(certificate, "Subjects"),
    Resource::certificate,
  )
}
