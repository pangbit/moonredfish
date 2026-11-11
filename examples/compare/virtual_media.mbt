///|
fn virtual_media_json(item : @moonredfish.VirtualMedia) -> Json {
  {
    "uri": @json.to_json(item.resource.uri),
    "id": optional(item.resource.id),
    "fields": {
      "ConnectedVia": parity_value(item.connected_via),
      "EjectPolicy": parity_value(item.eject_policy),
      "EjectTimeout": parity_value(item.eject_timeout),
      "Image": parity_value(item.image),
      "ImageName": parity_value(item.image_name),
      "MediaType": parity_value(item.media_type),
      "TransferMethod": parity_value(item.transfer_method),
      "TransferProtocolType": parity_value(item.transfer_protocol_type),
      "UserName": parity_value(item.user_name),
      "Inserted": parity_value(item.inserted),
      "VerifyCertificate": parity_value(item.verify_certificate),
      "WriteProtected": parity_value(item.write_protected),
      "MediaTypes": parity_value(item.media_types),
      "Status": pcie_health(item.status),
      "SupportsMediaEject": @json.to_json(item.supports_media_eject),
      "SupportsMediaInsert": @json.to_json(item.supports_media_insert),
    },
  }
}

///|
async fn virtual_media_inventory(c : @moonredfish.Client) -> Json {
  guard c.get("/redfish/v1/VirtualMediaTests").json
    is { "Cases": Array(cases), .. } else {
    fail("invalid virtual media manifest")
  }
  let out : Map[String, Json] = Map([])
  for probe in cases {
    guard probe
      is { "ID": String(id), "URI": String(uri), "Kind": String(kind), .. } else {
      fail("invalid virtual media case")
    }
    out[id] = try {
      let owner = c.get(uri)
      let result = match kind {
        "media" => virtual_media_json(owner.virtual_media())
        "system_media" | "manager_media" =>
          boot_items(c.virtual_media(owner), virtual_media_json)
        "server_certificates" =>
          boot_items(c.certificates(owner), certificate_json)
        "client_certificates" =>
          boot_items(
            c.virtual_media_client_certificates(owner),
            certificate_json,
          )
        _ => fail("invalid virtual media operation")
      }
      { "ok": true, "error": "", "value": result }
    } catch {
      @moonredfish.InvalidResponse(_) =>
        { "ok": false, "error": "invalid_response", "value": @json.null }
      @moonredfish.InvalidPath =>
        { "ok": false, "error": "invalid_path", "value": @json.null }
      @moonredfish.DetailedHttpStatus(_) =>
        { "ok": false, "error": "http", "value": @json.null }
      _ => fail("unexpected virtual media fixture error")
    }
  }
  { "cases": @json.to_json(out) }
}
