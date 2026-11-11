///|
/// Reported boot configuration. Lists retain order and strings are not executed.
pub struct Boot {
  json : Json
  automatic_retry_config : Field[String]
  boot_next : Field[String]
  boot_order_property_selection : Field[String]
  boot_source_override_enabled : Field[String]
  boot_source_override_mode : Field[String]
  boot_source_override_target : Field[String]
  http_boot_uri : Field[String]
  stop_boot_on_fault : Field[String]
  trusted_module_required_to_boot : Field[String]
  uefi_target_boot_source_override : Field[String]
  alias_boot_order : Field[Array[String]]
  boot_order : Field[Array[String]]
  allowable_boot_source_override_target_values : Field[Array[String]]
  allowable_uefi_target_boot_source_override_values : Field[Array[String]]
}

///|
fn parse_boot(value : Json) -> Boot raise RedfishError {
  require_object(value)
  {
    json: value,
    automatic_retry_config: read_field(
      value, "AutomaticRetryConfig", string_value,
    ),
    boot_next: read_field(value, "BootNext", string_value),
    boot_order_property_selection: read_field(
      value, "BootOrderPropertySelection", string_value,
    ),
    boot_source_override_enabled: read_field(
      value, "BootSourceOverrideEnabled", string_value,
    ),
    boot_source_override_mode: read_field(
      value, "BootSourceOverrideMode", string_value,
    ),
    boot_source_override_target: read_field(
      value, "BootSourceOverrideTarget", string_value,
    ),
    http_boot_uri: read_field(value, "HttpBootUri", string_value),
    stop_boot_on_fault: read_field(value, "StopBootOnFault", string_value),
    trusted_module_required_to_boot: read_field(
      value, "TrustedModuleRequiredToBoot", string_value,
    ),
    uefi_target_boot_source_override: read_field(
      value, "UefiTargetBootSourceOverride", string_value,
    ),
    alias_boot_order: read_array(value, "AliasBootOrder", string_value),
    boot_order: read_array(value, "BootOrder", string_value),
    allowable_boot_source_override_target_values: read_array(
      value, "BootSourceOverrideTarget@Redfish.AllowableValues", string_value,
    ),
    allowable_uefi_target_boot_source_override_values: read_array(
      value, "UefiTargetBootSourceOverride@Redfish.AllowableValues", string_value,
    ),
  }
}

///|
/// Reads ComputerSystem.Boot without changing the existing SystemInfo view.
pub fn Resource::boot(self : Resource) -> Field[Boot] raise RedfishError {
  read_field(self.json, "Boot", parse_boot)
}

///|
pub struct BootOption {
  resource : Resource
  boot_alias : Field[String]
  boot_option_reference : Field[String]
  display_name : Field[String]
  uefi_device_path : Field[String]
  boot_option_enabled : Field[Bool]
}

///|
pub fn Resource::boot_option(self : Resource) -> BootOption raise RedfishError {
  {
    resource: self,
    boot_alias: read_field(self.json, "Alias", string_value),
    boot_option_reference: read_field(
      self.json,
      "BootOptionReference",
      string_value,
    ),
    display_name: read_field(self.json, "DisplayName", string_value),
    uefi_device_path: read_field(self.json, "UefiDevicePath", string_value),
    boot_option_enabled: read_field(self.json, "BootOptionEnabled", bool_value),
  }
}

///|
/// Current-boot state and next-boot enablement remain distinct reported fields.
pub struct SecureBoot {
  resource : Resource
  secure_boot_current_boot : Field[String]
  secure_boot_mode : Field[String]
  secure_boot_enable : Field[Bool]
}

///|
pub fn Resource::secure_boot(self : Resource) -> SecureBoot raise RedfishError {
  {
    resource: self,
    secure_boot_current_boot: read_field(
      self.json,
      "SecureBootCurrentBoot",
      string_value,
    ),
    secure_boot_mode: read_field(self.json, "SecureBootMode", string_value),
    secure_boot_enable: read_field(self.json, "SecureBootEnable", bool_value),
  }
}

///|
pub struct SecureBootDatabase {
  resource : Resource
  database_id : Field[String]
}

///|
pub fn Resource::secure_boot_database(
  self : Resource,
) -> SecureBootDatabase raise RedfishError {
  {
    resource: self,
    database_id: read_field(self.json, "DatabaseId", string_value),
  }
}

///|
/// Signature contents remain caller data; no verification or signing is performed.
pub struct Signature {
  resource : Resource
  signature_string : Field[String]
  signature_type : Field[String]
  signature_type_registry : Field[String]
  uefi_signature_owner : Field[String]
}

///|
pub fn Resource::signature(self : Resource) -> Signature raise RedfishError {
  {
    resource: self,
    signature_string: read_field(self.json, "SignatureString", string_value),
    signature_type: read_field(self.json, "SignatureType", string_value),
    signature_type_registry: read_field(
      self.json,
      "SignatureTypeRegistry",
      string_value,
    ),
    uefi_signature_owner: read_field(
      self.json,
      "UefiSignatureOwner",
      string_value,
    ),
  }
}
