///|
test "boot preserves source order duplicates allowable values and unmodeled JSON" {
  let raw : Json = {
    "BootOrder": ["Boot0002", "Boot0001", "Boot0002"],
    "AliasBootOrder": ["Pxe", "FutureSource"],
    "BootSourceOverrideTarget": "FutureTarget",
    "BootSourceOverrideTarget@Redfish.AllowableValues": ["Pxe", "FutureTarget"],
    "HttpBootUri": "https://boot.example.invalid/image",
    "AutomaticRetryAttempts": 3,
    "Oem": { "Synthetic": true },
  }
  let boot = @moonredfish.parse_resource("/redfish/v1/Systems/demo", {
      "Boot": raw,
    })
    .boot()
    .value()
    .unwrap()
  assert_eq(boot.json, raw)
  assert_eq(boot.boot_order.value(), Some(["Boot0002", "Boot0001", "Boot0002"]))
  assert_eq(boot.alias_boot_order.value(), Some(["Pxe", "FutureSource"]))
  assert_eq(boot.boot_source_override_target.value(), Some("FutureTarget"))
  assert_eq(
    boot.allowable_boot_source_override_target_values.value(),
    Some(["Pxe", "FutureTarget"]),
  )
  assert_eq(
    boot.http_boot_uri.value(),
    Some("https://boot.example.invalid/image"),
  )
}

///|
test "boot presence and current versus next Secure Boot state stay distinct" {
  assert_true(
    @moonredfish.parse_resource("/redfish/v1/Systems/demo", {}).boot()
    is Missing,
  )
  assert_true(
    @moonredfish.parse_resource("/redfish/v1/Systems/demo", { "Boot": null }).boot()
    is Null,
  )
  let boot = @moonredfish.parse_resource("/redfish/v1/Systems/demo", {
      "Boot": { "BootNext": null, "BootOrder": [] },
    })
    .boot()
    .value()
    .unwrap()
  assert_true(boot.boot_next is Null)
  assert_true(boot.boot_source_override_enabled is Missing)
  assert_eq(boot.boot_order.value(), Some([]))
  let secure = @moonredfish.parse_resource(
    "/redfish/v1/Systems/demo/SecureBoot",
    { "SecureBootCurrentBoot": "Enabled", "SecureBootEnable": false },
  ).secure_boot()
  assert_eq(secure.secure_boot_current_boot.value(), Some("Enabled"))
  assert_eq(secure.secure_boot_enable.value(), Some(false))
  assert_true(secure.secure_boot_mode is Missing)
  let raw : Json = {
    "SignatureString": "001122",
    "SignatureType": "FutureSignature",
    "Oem": { "Synthetic": true },
  }
  let signature = @moonredfish.parse_resource(
    "/redfish/v1/Signatures/demo", raw,
  ).signature()
  assert_eq(signature.resource.json, raw)
  assert_eq(signature.signature_string.value(), Some("001122"))
  assert_eq(signature.signature_type.value(), Some("FutureSignature"))
}

///|
test "boot rejects malformed nested objects and list elements" {
  for
    raw in (
      [
        { "Boot": [] },
        { "Boot": { "BootOrder": [null] } },
        { "Boot": { "AliasBootOrder": [1] } },
        { "Boot": { "HttpBootUri": true } },
        {
          "Boot": { "BootSourceOverrideTarget@Redfish.AllowableValues": "Pxe" },
        },
      ] : Array[Json]) {
    assert_true(
      try {
        ignore(
          @moonredfish.parse_resource("/redfish/v1/Systems/demo", raw).boot(),
        )
        false
      } catch {
        @moonredfish.InvalidResponse(_) => true
        _ => false
      },
    )
  }
}
