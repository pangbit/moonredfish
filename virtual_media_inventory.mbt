///|
/// Reported virtual media metadata. Image URIs are data, never fetched or mounted.
pub struct VirtualMedia {
  resource : Resource
  connected_via : Field[String]
  eject_policy : Field[String]
  eject_timeout : Field[String]
  image : Field[String]
  image_name : Field[String]
  media_type : Field[String]
  transfer_method : Field[String]
  transfer_protocol_type : Field[String]
  user_name : Field[String]
  inserted : Field[Bool]
  verify_certificate : Field[Bool]
  write_protected : Field[Bool]
  media_types : Field[Array[String]]
  status : Field[Health]
  /// Nonempty advertised action target only; not authorization or target validation.
  supports_media_eject : Bool
  /// Nonempty advertised action target only; not authorization or target validation.
  supports_media_insert : Bool
}

///|
fn virtual_media_advertises(
  json : Json,
  action : String,
) -> Bool raise RedfishError {
  match read_field(json, "Actions", object_value) {
    Missing | Null => false
    Value(actions) =>
      match nested_field(actions, action, "target", string_value) {
        Missing | Null => false
        Value(target) => !target.is_empty()
      }
  }
}

///|
pub fn Resource::virtual_media(
  self : Resource,
) -> VirtualMedia raise RedfishError {
  {
    resource: self,
    connected_via: read_field(self.json, "ConnectedVia", string_value),
    eject_policy: read_field(self.json, "EjectPolicy", string_value),
    eject_timeout: read_field(self.json, "EjectTimeout", string_value),
    image: read_field(self.json, "Image", string_value),
    image_name: read_field(self.json, "ImageName", string_value),
    media_type: read_field(self.json, "MediaType", string_value),
    transfer_method: read_field(self.json, "TransferMethod", string_value),
    transfer_protocol_type: read_field(
      self.json,
      "TransferProtocolType",
      string_value,
    ),
    user_name: read_field(self.json, "UserName", string_value),
    inserted: read_field(self.json, "Inserted", bool_value),
    verify_certificate: read_field(self.json, "VerifyCertificate", bool_value),
    write_protected: read_field(self.json, "WriteProtected", bool_value),
    media_types: read_array(self.json, "MediaTypes", string_value),
    status: read_field(self.json, "Status", parse_health),
    supports_media_eject: virtual_media_advertises(
      self.json,
      "#VirtualMedia.EjectMedia",
    ),
    supports_media_insert: virtual_media_advertises(
      self.json,
      "#VirtualMedia.InsertMedia",
    ),
  }
}
