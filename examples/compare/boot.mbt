///|
fn boot_json(field : @moonredfish.Field[@moonredfish.Boot]) -> Json {
  match field {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(item) =>
      {
        "state": "value",
        "value": {
          "AutomaticRetryConfig": parity_value(item.automatic_retry_config),
          "BootNext": parity_value(item.boot_next),
          "BootOrderPropertySelection": parity_value(
            item.boot_order_property_selection,
          ),
          "BootSourceOverrideEnabled": parity_value(
            item.boot_source_override_enabled,
          ),
          "BootSourceOverrideMode": parity_value(item.boot_source_override_mode),
          "BootSourceOverrideTarget": parity_value(
            item.boot_source_override_target,
          ),
          "HttpBootUri": parity_value(item.http_boot_uri),
          "StopBootOnFault": parity_value(item.stop_boot_on_fault),
          "TrustedModuleRequiredToBoot": parity_value(
            item.trusted_module_required_to_boot,
          ),
          "UefiTargetBootSourceOverride": parity_value(
            item.uefi_target_boot_source_override,
          ),
          "AliasBootOrder": parity_value(item.alias_boot_order),
          "BootOrder": parity_value(item.boot_order),
          "BootSourceOverrideTarget@Redfish.AllowableValues": parity_value(
            item.allowable_boot_source_override_target_values,
          ),
          "UefiTargetBootSourceOverride@Redfish.AllowableValues": parity_value(
            item.allowable_uefi_target_boot_source_override_values,
          ),
        },
      }
  }
}

///|
fn boot_boot_option_json(item : @moonredfish.BootOption) -> Json {
  {
    "uri": @json.to_json(item.resource.uri),
    "id": optional(item.resource.id),
    "fields": {
      "Alias": parity_value(item.boot_alias),
      "BootOptionReference": parity_value(item.boot_option_reference),
      "DisplayName": parity_value(item.display_name),
      "UefiDevicePath": parity_value(item.uefi_device_path),
      "BootOptionEnabled": parity_value(item.boot_option_enabled),
    },
  }
}

///|
fn boot_secure_boot_json(item : @moonredfish.SecureBoot) -> Json {
  {
    "uri": @json.to_json(item.resource.uri),
    "id": optional(item.resource.id),
    "fields": {
      "SecureBootCurrentBoot": parity_value(item.secure_boot_current_boot),
      "SecureBootMode": parity_value(item.secure_boot_mode),
      "SecureBootEnable": parity_value(item.secure_boot_enable),
    },
  }
}

///|
fn boot_secure_boot_database_json(
  item : @moonredfish.SecureBootDatabase,
) -> Json {
  {
    "uri": @json.to_json(item.resource.uri),
    "id": optional(item.resource.id),
    "fields": { "DatabaseId": parity_value(item.database_id) },
  }
}

///|
fn boot_signature_json(item : @moonredfish.Signature) -> Json {
  {
    "uri": @json.to_json(item.resource.uri),
    "id": optional(item.resource.id),
    "fields": {
      "SignatureString": parity_value(item.signature_string),
      "SignatureType": parity_value(item.signature_type),
      "SignatureTypeRegistry": parity_value(item.signature_type_registry),
      "UefiSignatureOwner": parity_value(item.uefi_signature_owner),
    },
  }
}

///|
fn[T] boot_items(
  items : @moonredfish.Field[Array[T]],
  project : (T) -> Json,
) -> Json {
  match items {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(items) =>
      { "state": "value", "value": @json.to_json(items.map(project)) }
  }
}

///|
async fn boot_inventory(c : @moonredfish.Client) -> Json {
  guard c.get("/redfish/v1/BootTests").json is { "Cases": Array(cases), .. } else {
    fail("invalid boot manifest")
  }
  let out : Map[String, Json] = Map([])
  for probe in cases {
    guard probe
      is { "ID": String(id), "URI": String(uri), "Kind": String(kind), .. } else {
      fail("invalid boot case")
    }
    out[id] = try {
      let owner = c.get(uri)
      let result = match kind {
        "boot" => boot_json(owner.boot())
        "boot_metadata" => {
          let boot = owner.boot()
          {
            "boot": boot_json(boot),
            "raw": owner.json,
            "boot_raw": boot.value().unwrap().json,
          }
        }
        "option" => boot_boot_option_json(owner.boot_option())
        "secure" => boot_secure_boot_json(owner.secure_boot())
        "database" =>
          boot_secure_boot_database_json(owner.secure_boot_database())
        "signature" => boot_signature_json(owner.signature())
        "boot_options" | "system_boot_options" =>
          boot_items(c.boot_options(owner), boot_boot_option_json)
        "secure_boot" =>
          match c.secure_boot(owner) {
            Missing => { "state": "missing" }
            Null => { "state": "null" }
            Value(item) =>
              { "state": "value", "value": boot_secure_boot_json(item) }
          }
        "databases" =>
          boot_items(
            c.secure_boot_databases(owner),
            boot_secure_boot_database_json,
          )
        "signatures" => boot_items(c.signatures(owner), boot_signature_json)
        _ => fail("invalid boot operation")
      }
      { "ok": true, "error": "", "value": result }
    } catch {
      @moonredfish.InvalidResponse(_) =>
        { "ok": false, "error": "invalid_response", "value": @json.null }
      @moonredfish.DetailedHttpStatus(_) =>
        { "ok": false, "error": "http", "value": @json.null }
      _ => fail("unexpected boot fixture error")
    }
  }
  { "cases": @json.to_json(out) }
}
