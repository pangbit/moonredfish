///|
/// Follows an explicit ComputerSystem or Manager VirtualMedia collection.
pub async fn Client::virtual_media(
  self : Client,
  owner : Resource,
) -> Field[Array[VirtualMedia]] {
  match self.linked_members(owner, "VirtualMedia") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::virtual_media))
  }
}

///|
/// Reads VirtualMedia.ClientCertificates separately from its server Certificates collection.
pub async fn Client::virtual_media_client_certificates(
  self : Client,
  media : Resource,
) -> Field[Array[Certificate]] {
  match self.linked_members(media, "ClientCertificates") {
    Missing => Missing
    Null => Null
    Value(items) => Value(items.map(Resource::certificate))
  }
}
