///|
test "Ethernet DHCP and SLAAC preserve values and original objects" {
  let dhcp4 : Json = {
    "DHCPEnabled": false,
    "FallbackAddress": "FutureFallback",
    "UseDNSServers": true,
    "UseDomainName": false,
    "UseGateway": true,
    "UseNTPServers": false,
    "UseStaticRoutes": true,
    "Oem": { "Synthetic": true },
  }
  let raw : Json = {
    "DHCPv4": dhcp4,
    "DHCPv6": { "OperatingMode": "FutureMode", "UseRapidCommit": false },
    "StatelessAddressAutoConfig": {
      "IPv4AutoConfigEnabled": false,
      "IPv6AutoConfigEnabled": true,
    },
    "NameServers": ["192.0.2.2", "2001:db8::53", "192.0.2.2"],
    "StaticNameServers": [],
  }
  let iface = @moonredfish.parse_resource(
    "/redfish/v1/EthernetInterfaces/0", raw,
  ).ethernet_interface()
  let d4 = iface.dhcpv4.value().unwrap()
  assert_eq(d4.json, dhcp4)
  assert_eq(d4.dhcp_enabled.value(), Some(false))
  assert_eq(d4.fallback_address.value(), Some("FutureFallback"))
  assert_eq(d4.use_dns_servers.value(), Some(true))
  assert_eq(d4.use_static_routes.value(), Some(true))
  assert_eq(
    iface.dhcpv6.value().unwrap().operating_mode.value(),
    Some("FutureMode"),
  )
  assert_eq(
    iface.stateless_address_auto_config.value().unwrap().ipv6_auto_config_enabled.value(),
    Some(true),
  )
  assert_eq(
    iface.name_servers.value(),
    Some(["192.0.2.2", "2001:db8::53", "192.0.2.2"]),
  )
  assert_eq(iface.static_name_servers.value(), Some([]))
  assert_eq(iface.resource.json, raw)
}

///|
test "network configuration retains absent null and nested default distinctions" {
  let raw : Json = {
    "DHCPv4": null,
    "DHCPv6": { "UseDNSServers": null, "UseRapidCommit": false },
    "StatelessAddressAutoConfig": {},
    "IPv6DefaultGateway": "2001:db8::1",
    "NameServers": null,
  }
  let iface = @moonredfish.parse_resource(
    "/redfish/v1/EthernetInterfaces/0", raw,
  ).ethernet_interface()
  assert_true(iface.dhcpv4 is Null)
  assert_true(iface.dhcpv6.value().unwrap().use_dns_servers is Null)
  assert_true(iface.dhcpv6.value().unwrap().use_domain_name is Missing)
  assert_eq(iface.dhcpv6.value().unwrap().use_rapid_commit.value(), Some(false))
  assert_true(
    iface.stateless_address_auto_config.value().unwrap().ipv6_auto_config_enabled
    is Missing,
  )
  assert_true(iface.name_servers is Null)
  assert_true(iface.static_name_servers is Missing)
  // Presence of a gateway does not invent an IPv6Enabled value or TeamMode.
  assert_true(iface.ipv6_enabled is Missing)
  assert_true(iface.team_mode is Missing)
}

///|
test "network configuration rejects malformed objects fields and DNS array members" {
  for
    raw in (
      [
        { "DHCPv4": false },
        { "DHCPv6": { "UseRapidCommit": "false" } },
        { "StatelessAddressAutoConfig": [] },
        { "NameServers": [null] },
        { "StaticNameServers": [1] },
        { "AutoNeg": "true" },
      ] : Array[Json]) {
    assert_true(
      try {
        ignore(
          @moonredfish.parse_resource("/redfish/v1/EthernetInterfaces/0", raw).ethernet_interface(),
        )
        false
      } catch {
        @moonredfish.InvalidResponse(_) => true
        _ => false
      },
    )
  }
}
