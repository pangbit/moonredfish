///|
test "certificate identifiers retain reported order text and raw metadata" {
  let identity : Json = {
    "CommonName": "leaf.example.invalid",
    "AdditionalCommonNames": ["second", "first", "second"],
    "AlternativeNames": ["alt.example.invalid"],
    "DomainComponents": ["example", "invalid"],
    "Oem": { "Synthetic": true },
  }
  let raw : Json = {
    "CertificateString": "synthetic-not-a-real-certificate",
    "CertificateType": "FutureFormat",
    "Fingerprint": "aA:00:bB",
    "SerialNumber": "00Af",
    "KeyUsage": ["FutureUsage", "FutureUsage"],
    "Subject": identity,
    "Issuer": { "CommonName": "issuer.example.invalid" },
    "ValidNotBefore": "future-date-format",
    "SPDM": { "SlotId": 3 },
  }
  let cert = @moonredfish.parse_resource("/redfish/v1/Certificates/demo", raw).certificate()
  assert_eq(cert.resource.json, raw)
  assert_eq(
    cert.certificate_string.value(),
    Some("synthetic-not-a-real-certificate"),
  )
  assert_eq(cert.certificate_type.value(), Some("FutureFormat"))
  assert_eq(cert.fingerprint.value(), Some("aA:00:bB"))
  assert_eq(cert.serial_number.value(), Some("00Af"))
  assert_eq(cert.key_usage.value(), Some(["FutureUsage", "FutureUsage"]))
  assert_eq(cert.subject.value().unwrap().json, identity)
  assert_eq(
    cert.subject.value().unwrap().additional_common_names.value(),
    Some(["second", "first", "second"]),
  )
  assert_eq(
    cert.issuer.value().unwrap().common_name.value(),
    Some("issuer.example.invalid"),
  )
  assert_eq(cert.valid_not_before.value(), Some("future-date-format"))
}

///|
test "certificate presence differs from empty identifiers and lists" {
  let cert = @moonredfish.parse_resource("/redfish/v1/Certificates/demo", {
    "CertificateString": "",
    "Issuer": null,
    "Subject": { "CommonName": null, "AlternativeNames": [] },
    "KeyUsage": [],
    "Status": { "Health": null },
  }).certificate()
  assert_eq(cert.certificate_string.value(), Some(""))
  assert_true(cert.certificate_type is Missing)
  assert_true(cert.issuer is Null)
  assert_true(cert.subject.value().unwrap().common_name is Null)
  assert_true(cert.subject.value().unwrap().country is Missing)
  assert_eq(cert.subject.value().unwrap().alternative_names.value(), Some([]))
  assert_eq(cert.key_usage.value(), Some([]))
  assert_true(cert.status.value().unwrap().health is Null)
}

///|
test "certificate readers reject malformed selected fields and null array elements" {
  for
    raw in (
      [
        { "Issuer": [] },
        { "Subject": { "AlternativeNames": [null] } },
        { "KeyUsage": [null] },
        { "CertificateUsageTypes": "Web" },
        { "CertificateString": false },
        { "ValidNotAfter": 123 },
      ] : Array[Json]) {
    assert_true(
      try {
        ignore(
          @moonredfish.parse_resource("/redfish/v1/Certificates/demo", raw).certificate(),
        )
        false
      } catch {
        @moonredfish.InvalidResponse(_) => true
        _ => false
      },
    )
  }
}
