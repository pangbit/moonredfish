///|
/// Read-only DHCPv4 settings reported by an EthernetInterface.
pub struct DHCPv4Configuration {
  json : Json
  dhcp_enabled : Field[Bool]
  fallback_address : Field[String]
  use_dns_servers : Field[Bool]
  use_domain_name : Field[Bool]
  use_gateway : Field[Bool]
  use_ntp_servers : Field[Bool]
  use_static_routes : Field[Bool]
}

///|
fn parse_dhcpv4_configuration(
  value : Json,
) -> DHCPv4Configuration raise RedfishError {
  require_object(value)
  {
    json: value,
    dhcp_enabled: read_field(value, "DHCPEnabled", bool_value),
    fallback_address: read_field(value, "FallbackAddress", string_value),
    use_dns_servers: read_field(value, "UseDNSServers", bool_value),
    use_domain_name: read_field(value, "UseDomainName", bool_value),
    use_gateway: read_field(value, "UseGateway", bool_value),
    use_ntp_servers: read_field(value, "UseNTPServers", bool_value),
    use_static_routes: read_field(value, "UseStaticRoutes", bool_value),
  }
}

///|
pub struct DHCPv6Configuration {
  json : Json
  operating_mode : Field[String]
  use_dns_servers : Field[Bool]
  use_domain_name : Field[Bool]
  use_ntp_servers : Field[Bool]
  use_rapid_commit : Field[Bool]
}

///|
fn parse_dhcpv6_configuration(
  value : Json,
) -> DHCPv6Configuration raise RedfishError {
  require_object(value)
  {
    json: value,
    operating_mode: read_field(value, "OperatingMode", string_value),
    use_dns_servers: read_field(value, "UseDNSServers", bool_value),
    use_domain_name: read_field(value, "UseDomainName", bool_value),
    use_ntp_servers: read_field(value, "UseNTPServers", bool_value),
    use_rapid_commit: read_field(value, "UseRapidCommit", bool_value),
  }
}

///|
pub struct StatelessAddressAutoConfiguration {
  json : Json
  ipv4_auto_config_enabled : Field[Bool]
  ipv6_auto_config_enabled : Field[Bool]
}

///|
fn parse_stateless_address_auto_configuration(
  value : Json,
) -> StatelessAddressAutoConfiguration raise RedfishError {
  require_object(value)
  {
    json: value,
    ipv4_auto_config_enabled: read_field(
      value, "IPv4AutoConfigEnabled", bool_value,
    ),
    ipv6_auto_config_enabled: read_field(
      value, "IPv6AutoConfigEnabled", bool_value,
    ),
  }
}
