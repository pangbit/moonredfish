///|
/// Test-only adapter. The runner supplies public samples or synthetic loopback data.
fn optional(value : String?) -> Json {
  match value {
    Some(value) => @json.to_json(value)
    None => @json.null
  }
}

///|
fn project(resource : @moonredfish.Resource) -> Json {
  {
    "uri": @json.to_json(resource.uri),
    "id": optional(resource.id),
    "name": optional(resource.name),
    "type": optional(resource.resource_type),
    "power": optional(resource.string("PowerState")),
  }
}

///|
async fn protocol(c : @moonredfish.Client) -> Json {
  let wrong = try {
    c.login("synthetic-user", "synthetic-wrong")
    0
  } catch {
    @moonredfish.DetailedHttpStatus(info) => info.status
    _ => 0
  }
  c.with_session("synthetic-user", "synthetic-password", async fn(client) {
    let systems = client.systems().map(project)
    let empty = client.chassis().length()
    let forbidden : Json = try {
      ignore(client.get("/redfish/v1/Forbidden"))
      @json.null
    } catch {
      @moonredfish.DetailedHttpStatus(info) =>
        {
          "status": @json.to_json(info.status),
          "code": optional(info.code),
          "message_ids": @json.to_json(info.message_ids),
        }
      _ => @json.null
    }
    let missing = try {
      ignore(client.get("/redfish/v1/Missing"))
      0
    } catch {
      @moonredfish.DetailedHttpStatus(info) => info.status
      _ => 0
    }
    let invalid = try {
      ignore(client.get("/redfish/v1/Invalid"))
      false
    } catch {
      @moonredfish.InvalidResponse(_) => true
      _ => false
    }
    let cycle = try {
      ignore(client.members("/redfish/v1/Cycle"))
      false
    } catch {
      @moonredfish.PaginationCycle => true
      _ => false
    }
    {
      "wrong_password": @json.to_json(wrong),
      "systems": @json.to_json(systems),
      "empty_chassis": @json.to_json(empty),
      "forbidden": forbidden,
      "missing": @json.to_json(missing),
      "invalid_json": @json.to_json(invalid),
      "pagination_cycle": @json.to_json(cycle),
    }
  })
}

///|
async fn main {
  let args = @env.args()
  guard args.length() == 4 else { fail("run via python3 tools/test_gofish.py") }
  // Never turn this synthetic-credential test adapter into a device CLI.
  let port = if args[2].has_prefix("http://127.0.0.1:") {
    args[2][17:]
  } else if args[2].has_prefix("https://127.0.0.1:") {
    args[2][18:]
  } else {
    fail("comparison requires numeric loopback")
  }
  guard !port.is_empty() else { fail("comparison requires a port") }
  for c in port {
    guard c >= '0' && c <= '9' else { fail("invalid comparison port") }
  }
  let ca = if args[3] == "-" { None } else { Some(args[3]) }
  let c = @moonredfish.Client::new(
    args[2],
    ca_file?=ca,
    allow_loopback_http=true,
    detailed_errors=true,
  )
  let result : Json = match args[1] {
    "inventory" =>
      {
        "root": project(c.service_root()),
        "systems": @json.to_json(c.systems().map(project)),
        "chassis": @json.to_json(c.chassis().map(project)),
        "managers": @json.to_json(c.managers().map(project)),
      }
    "hardware" => hardware(c)
    "extended" => extended(c)
    "parity" => parity(c)
    "network-config" => network_config(c)
    "pcie" => pcie(c)
    "boot" => boot_inventory(c)
    "task" => task_inventory(c)
    "protocol" => protocol(c)
    "reject_tls" => {
      let rejected = try {
        ignore(c.service_root())
        false
      } catch {
        @tls.TlsError(_) => true
        _ => false
      }
      { "tls_rejected": @json.to_json(rejected) }
    }
    _ => fail("unknown comparison mode")
  }
  println(result.stringify())
}
