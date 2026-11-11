///|
fn[T] count(field : @moonredfish.Field[Array[T]]) -> String {
  match field {
    Missing => "missing"
    Null => "null"
    Value(items) => items.length().to_string()
  }
}

///|
fn[T] presence(field : @moonredfish.Field[T]) -> String {
  match field {
    Missing => "missing"
    Null => "null"
    Value(_) => "present"
  }
}

///|
async fn logs(
  client : @moonredfish.Client,
  owner : @moonredfish.Resource,
) -> Unit {
  let services = client.log_services(owner)
  println("log services: \{count(services)}")
  if services is Value(items) {
    for service in items {
      // Log messages, arguments and identifiers are intentionally not printed.
      println("log entries: \{count(client.log_entries(service.resource))}")
    }
  }
}

///|
async fn inventory(client : @moonredfish.Client) -> Unit {
  for system in client.systems() {
    let storage = client.storage(system)
    println("storage: \{count(storage)}")
    if storage is Value(items) {
      for item in items {
        println("drives: \{count(client.drives(item.resource))}")
        println("volumes: \{count(client.volumes(item.resource))}")
      }
    }
    println("system interfaces: \{count(client.ethernet_interfaces(system))}")
    let bios = client.bios(system)
    println("BIOS: \{presence(bios)}")
    if bios is Value(bios) {
      println("BIOS attributes: \{presence(bios.attributes)}")
    }
    logs(client, system)
  }
  for chassis in client.chassis() {
    println("network adapters: \{count(client.network_adapters(chassis))}")
    logs(client, chassis)
  }
  for manager in client.managers() {
    println("manager interfaces: \{count(client.ethernet_interfaces(manager))}")
    logs(client, manager)
  }
  let update = client.update_service(client.service_root())
  println("update service: \{presence(update)}")
  if update is Value(service) {
    println("firmware inventory: \{count(client.firmware_inventory(service))}")
  }
}

///|
async fn main {
  let args = @env.args()
  if args.length() == 1 {
    // Safe offline default. No real device, credentials or private attributes.
    let drive = @moonredfish.parse_resource("/redfish/v1/Drives/demo", {
      "CapacityBytes": 0,
      "FailurePredicted": false,
    }).drive()
    println(
      "offline synthetic drive: capacity=\{presence(drive.capacity_bytes)}, failure_predicted=\{presence(drive.failure_predicted)}",
    )
    let pcie = @moonredfish.parse_resource("/redfish/v1/PCIeDevices/demo", {
      "PCIeInterface": { "LanesInUse": 4 },
      "ReadyToRemove": false,
    }).pcie_device()
    println(
      "offline synthetic PCIe: interface=\{presence(pcie.pcie_interface)}",
    )
    let interface = @moonredfish.parse_resource(
      "/redfish/v1/EthernetInterfaces/demo",
      { "DHCPv4": { "DHCPEnabled": false }, "NameServers": [] },
    ).ethernet_interface()
    println(
      "offline synthetic network: DHCPv4=\{presence(interface.dhcpv4)}, DNS servers=\{count(interface.name_servers)}",
    )
    let boot = @moonredfish.parse_resource("/redfish/v1/Systems/demo", {
        "Boot": { "BootOrder": ["Boot0002", "Boot0001"] },
      })
      .boot()
      .value()
      .unwrap()
    println("offline synthetic boot order entries: \{count(boot.boot_order)}")
    let secure = @moonredfish.parse_resource(
      "/redfish/v1/Systems/demo/SecureBoot",
      { "SecureBootCurrentBoot": "Enabled", "SecureBootEnable": false },
    ).secure_boot()
    println(
      "offline synthetic Secure Boot: current=\{presence(secure.secure_boot_current_boot)}, next=\{presence(secure.secure_boot_enable)}",
    )
    let task = @moonredfish.parse_resource(
      "/redfish/v1/TaskService/Tasks/demo",
      { "TaskState": "Running", "PercentComplete": 0, "Messages": [] },
    ).task()
    println(
      "offline synthetic task: state=\{presence(task.task_state)}, progress=\{presence(task.percent_complete)}, messages=\{count(task.messages)}",
    )
    let certificate = @moonredfish.parse_resource(
      "/redfish/v1/Certificates/demo",
      {
        "CertificateType": "PEM",
        "Subject": { "CommonName": "synthetic.example.invalid" },
        "KeyUsage": [],
      },
    ).certificate()
    println(
      "offline synthetic certificate: subject=\{presence(certificate.subject)}, key usages=\{count(certificate.key_usage)}",
    )
    let media = @moonredfish.parse_resource(
      "/redfish/v1/Systems/demo/VirtualMedia/demo",
      { "Inserted": false, "WriteProtected": true, "MediaTypes": ["CD", "DVD"] },
    ).virtual_media()
    println(
      "offline synthetic virtual media: inserted=\{presence(media.inserted)}, supported types=\{count(media.media_types)}",
    )
    let info = @moonredfish.parse_resource("/redfish/v1/ActionInfo/demo", {
      "Parameters": [
        { "Name": "Mode", "DataType": "String", "AllowableValues": ["A", "B"] },
      ],
    }).action_info()
    println(
      "offline synthetic action metadata: values=\{count(info.param_values("Mode", "String"))}",
    )
    let bios = @moonredfish.parse_resource("/redfish/v1/Systems/demo/Bios", {
      "Attributes": null,
    }).bios()
    println("offline synthetic BIOS attributes: \{presence(bios.attributes)}")
  } else {
    guard args.length() == 2 else {
      fail("usage: extended [https://authorized-bmc.example.invalid]")
    }
    let ca_file = @env.get_env_var("REDFISH_CA_FILE")
    let client = @moonredfish.Client::new(args[1], ca_file?)
    match
      (
        @env.get_env_var("REDFISH_USERNAME"),
        @env.get_env_var("REDFISH_PASSWORD"),
      ) {
      (None, None) => inventory(client)
      (Some(username), Some(password)) if !username.is_empty() &&
        !password.is_empty() =>
        client.with_session(username, password, inventory)
      _ =>
        fail(
          "supply both nonempty REDFISH_USERNAME and REDFISH_PASSWORD, or neither",
        )
    }
  }
}
