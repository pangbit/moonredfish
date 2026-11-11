///|
fn certificate_identifier_json(
  field : @moonredfish.Field[@moonredfish.CertificateIdentifier],
) -> Json {
  match field {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(item) =>
      {
        "state": "value",
        "value": {
          "City": parity_value(item.city),
          "CommonName": parity_value(item.common_name),
          "Country": parity_value(item.country),
          "DisplayString": parity_value(item.display_string),
          "Email": parity_value(item.email),
          "Organization": parity_value(item.organization),
          "OrganizationalUnit": parity_value(item.organizational_unit),
          "State": parity_value(item.state),
          "AdditionalCommonNames": parity_value(item.additional_common_names),
          "AdditionalOrganizationalUnits": parity_value(
            item.additional_organizational_units,
          ),
          "AlternativeNames": parity_value(item.alternative_names),
          "DomainComponents": parity_value(item.domain_components),
        },
      }
  }
}

///|
fn certificate_json(item : @moonredfish.Certificate) -> Json {
  {
    "uri": @json.to_json(item.resource.uri),
    "id": optional(item.resource.id),
    "fields": {
      "CertificateString": parity_value(item.certificate_string),
      "CertificateType": parity_value(item.certificate_type),
      "Fingerprint": parity_value(item.fingerprint),
      "FingerprintHashAlgorithm": parity_value(item.fingerprint_hash_algorithm),
      "SerialNumber": parity_value(item.serial_number),
      "SignatureAlgorithm": parity_value(item.signature_algorithm),
      "UefiSignatureOwner": parity_value(item.uefi_signature_owner),
      "ValidNotAfter": parity_value(item.valid_not_after),
      "ValidNotBefore": parity_value(item.valid_not_before),
      "CertificateUsageTypes": parity_value(item.certificate_usage_types),
      "KeyUsage": parity_value(item.key_usage),
      "Issuer": certificate_identifier_json(item.issuer),
      "Subject": certificate_identifier_json(item.subject),
      "Status": pcie_health(item.status),
    },
  }
}

///|
fn certificate_resource(
  field : @moonredfish.Field[@moonredfish.Resource],
) -> Json {
  match field {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(item) => { "state": "value", "value": task_entity_json(item) }
  }
}

///|
async fn certificate_inventory(c : @moonredfish.Client) -> Json {
  guard c.get("/redfish/v1/CertificateTests").json
    is { "Cases": Array(cases), .. } else {
    fail("invalid certificate manifest")
  }
  let out : Map[String, Json] = Map([])
  for probe in cases {
    guard probe
      is { "ID": String(id), "URI": String(uri), "Kind": String(kind), .. } else {
      fail("invalid certificate case")
    }
    out[id] = try {
      let owner = c.get(uri)
      let result = match kind {
        "certificate" => certificate_json(owner.certificate())
        "service" => certificate_resource(c.certificate_service(owner))
        "locations" => certificate_resource(c.certificate_locations(owner))
        "system_certificates" | "database_certificates" =>
          boot_items(c.certificates(owner), certificate_json)
        "boot_certificates" =>
          boot_items(c.boot_certificates(owner), certificate_json)
        "located" =>
          boot_items(
            c.certificate_location_certificates(owner),
            certificate_json,
          )
        "subjects" =>
          boot_items(c.certificate_subjects(owner), certificate_json)
        _ => fail("invalid certificate operation")
      }
      { "ok": true, "error": "", "value": result }
    } catch {
      @moonredfish.InvalidResponse(_) =>
        { "ok": false, "error": "invalid_response", "value": @json.null }
      @moonredfish.InvalidPath =>
        { "ok": false, "error": "invalid_path", "value": @json.null }
      @moonredfish.DetailedHttpStatus(_) =>
        { "ok": false, "error": "http", "value": @json.null }
      _ => fail("unexpected certificate fixture error")
    }
  }
  { "cases": @json.to_json(out) }
}
