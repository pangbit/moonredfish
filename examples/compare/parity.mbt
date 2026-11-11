///|
/// Preserve Field states; this observation format is not an approved API mapping.
fn[T : @json.ToJson] parity_value(field : @moonredfish.Field[T]) -> Json {
  match field {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(value) => { "state": "value", "value": @json.to_json(value) }
  }
}

///|
async fn parity(c : @moonredfish.Client) -> Json {
  let manifest = c.get("/redfish/v1/Parity").json
  guard manifest is { "Cases": Array(cases), .. } else {
    fail("invalid parity manifest")
  }
  let out : Map[String, Json] = Map([])
  for probe in cases {
    guard probe
      is {
        "ID": String(id),
        "Kind": String(kind),
        "URI": String(uri),
        "Field": String(field),
        ..
      } else {
      fail("invalid parity case")
    }
    out[id] = try {
      let value : Json = if kind == "drive" {
        let item = c.get(uri).drive()
        match field {
          "CapacityBytes" => parity_value(item.capacity_bytes)
          "FailurePredicted" => parity_value(item.failure_predicted)
          "Protocol" => parity_value(item.protocol)
          "SerialNumber" => parity_value(item.serial_number)
          _ => fail("unknown parity field")
        }
      } else {
        let members : Array[Json] = []
        for link in c.members(uri) {
          let item = c.get(link)
          members.push({ "id": optional(item.id), "name": optional(item.name) })
        }
        @json.to_json(members)
      }
      { "ok": true, "error": "", "value": value }
    } catch {
      @moonredfish.InvalidResponse(_) =>
        { "ok": false, "error": "invalid_response", "value": @json.null }
      @moonredfish.DetailedHttpStatus(_) =>
        { "ok": false, "error": "http", "value": @json.null }
      @moonredfish.PaginationCycle =>
        { "ok": false, "error": "pagination_cycle", "value": @json.null }
      _ => fail("unclassified synthetic moonredfish error")
    }
  }
  { "cases": @json.to_json(out) }
}
