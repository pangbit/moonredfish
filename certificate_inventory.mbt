///|
/// Reported certificate identity, not a parsed or verified X.509 identity.
pub struct CertificateIdentifier {
  json : Json
  city : Field[String]
  common_name : Field[String]
  country : Field[String]
  display_string : Field[String]
  email : Field[String]
  organization : Field[String]
  organizational_unit : Field[String]
  state : Field[String]
  additional_common_names : Field[Array[String]]
  additional_organizational_units : Field[Array[String]]
  alternative_names : Field[Array[String]]
  domain_components : Field[Array[String]]
}

///|
fn parse_certificate_identifier(
  value : Json,
) -> CertificateIdentifier raise RedfishError {
  require_object(value)
  {
    json: value,
    city: read_field(value, "City", string_value),
    common_name: read_field(value, "CommonName", string_value),
    country: read_field(value, "Country", string_value),
    display_string: read_field(value, "DisplayString", string_value),
    email: read_field(value, "Email", string_value),
    organization: read_field(value, "Organization", string_value),
    organizational_unit: read_field(value, "OrganizationalUnit", string_value),
    state: read_field(value, "State", string_value),
    additional_common_names: read_array(
      value, "AdditionalCommonNames", string_value,
    ),
    additional_organizational_units: read_array(
      value, "AdditionalOrganizationalUnits", string_value,
    ),
    alternative_names: read_array(value, "AlternativeNames", string_value),
    domain_components: read_array(value, "DomainComponents", string_value),
  }
}

///|
/// Reported metadata only; no parsing, trust installation, validation or renewal.
pub struct Certificate {
  resource : Resource
  certificate_string : Field[String]
  certificate_type : Field[String]
  fingerprint : Field[String]
  fingerprint_hash_algorithm : Field[String]
  serial_number : Field[String]
  signature_algorithm : Field[String]
  uefi_signature_owner : Field[String]
  valid_not_after : Field[String]
  valid_not_before : Field[String]
  certificate_usage_types : Field[Array[String]]
  key_usage : Field[Array[String]]
  issuer : Field[CertificateIdentifier]
  subject : Field[CertificateIdentifier]
  status : Field[Health]
}

///|
pub fn Resource::certificate(self : Resource) -> Certificate raise RedfishError {
  {
    resource: self,
    certificate_string: read_field(self.json, "CertificateString", string_value),
    certificate_type: read_field(self.json, "CertificateType", string_value),
    fingerprint: read_field(self.json, "Fingerprint", string_value),
    fingerprint_hash_algorithm: read_field(
      self.json,
      "FingerprintHashAlgorithm",
      string_value,
    ),
    serial_number: read_field(self.json, "SerialNumber", string_value),
    signature_algorithm: read_field(
      self.json,
      "SignatureAlgorithm",
      string_value,
    ),
    uefi_signature_owner: read_field(
      self.json,
      "UefiSignatureOwner",
      string_value,
    ),
    valid_not_after: read_field(self.json, "ValidNotAfter", string_value),
    valid_not_before: read_field(self.json, "ValidNotBefore", string_value),
    certificate_usage_types: read_array(
      self.json,
      "CertificateUsageTypes",
      string_value,
    ),
    key_usage: read_array(self.json, "KeyUsage", string_value),
    issuer: read_field(self.json, "Issuer", parse_certificate_identifier),
    subject: read_field(self.json, "Subject", parse_certificate_identifier),
    status: read_field(self.json, "Status", parse_health),
  }
}
