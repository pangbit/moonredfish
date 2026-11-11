///|
fn network_dhcpv4(
  field : @moonredfish.Field[@moonredfish.DHCPv4Configuration],
) -> Json {
  match field {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(item) =>
      {
        "state": "value",
        "value": {
          "DHCPEnabled": parity_value(item.dhcp_enabled),
          "FallbackAddress": parity_value(item.fallback_address),
          "UseDNSServers": parity_value(item.use_dns_servers),
          "UseDomainName": parity_value(item.use_domain_name),
          "UseGateway": parity_value(item.use_gateway),
          "UseNTPServers": parity_value(item.use_ntp_servers),
          "UseStaticRoutes": parity_value(item.use_static_routes),
        },
      }
  }
}

///|
fn network_dhcpv6(
  field : @moonredfish.Field[@moonredfish.DHCPv6Configuration],
) -> Json {
  match field {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(item) =>
      {
        "state": "value",
        "value": {
          "OperatingMode": parity_value(item.operating_mode),
          "UseDNSServers": parity_value(item.use_dns_servers),
          "UseDomainName": parity_value(item.use_domain_name),
          "UseNTPServers": parity_value(item.use_ntp_servers),
          "UseRapidCommit": parity_value(item.use_rapid_commit),
        },
      }
  }
}

///|
fn network_slaac(
  field : @moonredfish.Field[@moonredfish.StatelessAddressAutoConfiguration],
) -> Json {
  match field {
    Missing => { "state": "missing" }
    Null => { "state": "null" }
    Value(item) =>
      {
        "state": "value",
        "value": {
          "IPv4AutoConfigEnabled": parity_value(item.ipv4_auto_config_enabled),
          "IPv6AutoConfigEnabled": parity_value(item.ipv6_auto_config_enabled),
        },
      }
  }
}

///|
fn network_projection(item : @moonredfish.EthernetInterface) -> Json {
  {
    "AutoNeg": parity_value(item.auto_neg),
    "DHCPv4": network_dhcpv4(item.dhcpv4),
    "DHCPv6": network_dhcpv6(item.dhcpv6),
    "EthernetInterfaceType": parity_value(item.ethernet_interface_type),
    "IPv6DefaultGateway": parity_value(item.ipv6_default_gateway),
    "IPv6Enabled": parity_value(item.ipv6_enabled),
    "NameServers": parity_value(item.name_servers),
    "RoutingScope": parity_value(item.routing_scope),
    "StatelessAddressAutoConfig": network_slaac(
      item.stateless_address_auto_config,
    ),
    "StaticNameServers": parity_value(item.static_name_servers),
    "TeamMode": parity_value(item.team_mode),
    "UefiDevicePath": parity_value(item.uefi_device_path),
  }
}

///|
async fn network_config(c : @moonredfish.Client) -> Json {
  guard c.get("/redfish/v1/NetworkConfig").json is { "Cases": Array(cases), .. } else {
    fail("invalid network manifest")
  }
  let out : Map[String, Json] = Map([])
  for probe in cases {
    guard probe
      is { "ID": String(id), "URI": String(uri), "Kind": String(kind), .. } else {
      fail("invalid network case")
    }
    out[id] = try {
      let result = if kind == "collection" {
        guard c.ethernet_interfaces(c.get(uri)) is Value(items) else {
          fail("missing network fixture collection")
        }
        @json.to_json(items.map(network_projection))
      } else {
        network_projection(c.get(uri).ethernet_interface())
      }
      { "ok": true, "error": "", "value": result }
    } catch {
      @moonredfish.InvalidResponse(_) =>
        { "ok": false, "error": "invalid_response", "value": @json.null }
      _ => fail("unexpected network fixture error")
    }
  }
  { "cases": @json.to_json(out) }
}
