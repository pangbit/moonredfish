///|
test "virtual media retains independent reported states and raw metadata" {
  let raw : Json = {
    "Image": "https://media.example.invalid/synthetic.iso",
    "ImageName": "synthetic.iso",
    "MediaType": "FutureSelected",
    "MediaTypes": ["DVD", "CD", "DVD"],
    "ConnectedVia": "NotConnected",
    "Inserted": true,
    "VerifyCertificate": false,
    "WriteProtected": false,
    "EjectTimeout": "future-duration",
    "Actions": {
      "#VirtualMedia.InsertMedia": { "target": "/redfish/v1/MustNotInsert" },
      "#VirtualMedia.EjectMedia": {
        "@Redfish.ActionInfo": "/redfish/v1/MustNotFetchInfo",
      },
    },
    "SupportsMediaEject": true,
    "Oem": { "Synthetic": true },
  }
  let item = @moonredfish.parse_resource("/redfish/v1/VirtualMedia/demo", raw).virtual_media()
  assert_eq(item.resource.json, raw)
  assert_eq(
    item.image.value(),
    Some("https://media.example.invalid/synthetic.iso"),
  )
  assert_eq(item.media_type.value(), Some("FutureSelected"))
  assert_eq(item.media_types.value(), Some(["DVD", "CD", "DVD"]))
  assert_eq(item.connected_via.value(), Some("NotConnected"))
  assert_eq(item.inserted.value(), Some(true))
  assert_eq(item.write_protected.value(), Some(false))
  assert_eq(item.verify_certificate.value(), Some(false))
  assert_eq(item.eject_timeout.value(), Some("future-duration"))
  assert_true(item.supports_media_insert)
  assert_false(item.supports_media_eject)
}

///|
test "virtual media preserves field presence and derives only advertised action support" {
  let item = @moonredfish.parse_resource("/redfish/v1/VirtualMedia/demo", {
    "Image": null,
    "Inserted": null,
    "VerifyCertificate": null,
    "WriteProtected": false,
    "MediaTypes": [],
    "Actions": {
      "#VirtualMedia.EjectMedia": { "target": "" },
      "#VirtualMedia.InsertMedia": null,
    },
  }).virtual_media()
  assert_true(item.image is Null)
  assert_true(item.image_name is Missing)
  assert_true(item.inserted is Null)
  assert_true(item.verify_certificate is Null)
  assert_eq(item.write_protected.value(), Some(false))
  assert_eq(item.media_types.value(), Some([]))
  assert_false(item.supports_media_insert)
  assert_false(item.supports_media_eject)
  let absent = @moonredfish.parse_resource("/redfish/v1/VirtualMedia/demo", {}).virtual_media()
  assert_true(absent.inserted is Missing)
  assert_true(absent.verify_certificate is Missing)
  assert_false(absent.supports_media_insert)
}

///|
test "virtual media rejects malformed selected values and action targets" {
  for
    raw in (
      [
        { "Inserted": 0 },
        { "VerifyCertificate": "false" },
        { "Image": false },
        { "MediaTypes": [null] },
        { "Actions": [] },
        { "Actions": { "#VirtualMedia.EjectMedia": { "target": true } } },
      ] : Array[Json]) {
    assert_true(
      try {
        ignore(
          @moonredfish.parse_resource("/redfish/v1/VirtualMedia/demo", raw).virtual_media(),
        )
        false
      } catch {
        @moonredfish.InvalidResponse(_) => true
        _ => false
      },
    )
  }
}
