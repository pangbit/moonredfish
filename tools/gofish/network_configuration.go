// Read-only Ethernet configuration observations; never calls Update.
package main

import (
	"encoding/json"
	"github.com/stmcginnis/gofish"
	"github.com/stmcginnis/gofish/schemas"
)

func networkStrings(items []string) any {
	if items == nil {
		return map[string]any{"state": "nil"}
	}
	return parityValue(items)
}
func networkProjection(item *schemas.EthernetInterface) any {
	return map[string]any{
		"AutoNeg": parityValue(item.AutoNeg),
		"DHCPv4": parityValue(map[string]any{
			"DHCPEnabled":     parityValue(item.DHCPv4.DHCPEnabled),
			"FallbackAddress": parityValue(item.DHCPv4.FallbackAddress),
			"UseDNSServers":   parityValue(item.DHCPv4.UseDNSServers),
			"UseDomainName":   parityValue(item.DHCPv4.UseDomainName),
			"UseGateway":      parityValue(item.DHCPv4.UseGateway),
			"UseNTPServers":   parityValue(item.DHCPv4.UseNTPServers),
			"UseStaticRoutes": parityValue(item.DHCPv4.UseStaticRoutes),
		}),
		"DHCPv6": parityValue(map[string]any{
			"OperatingMode":  parityValue(item.DHCPv6.OperatingMode),
			"UseDNSServers":  parityValue(item.DHCPv6.UseDNSServers),
			"UseDomainName":  parityValue(item.DHCPv6.UseDomainName),
			"UseNTPServers":  parityValue(item.DHCPv6.UseNTPServers),
			"UseRapidCommit": parityValue(item.DHCPv6.UseRapidCommit),
		}),
		"EthernetInterfaceType": parityValue(item.EthernetInterfaceType),
		"IPv6DefaultGateway":    parityValue(item.IPv6DefaultGateway),
		"IPv6Enabled":           parityValue(item.IPv6Enabled),
		"NameServers":           networkStrings(item.NameServers),
		"RoutingScope":          parityValue(item.RoutingScope),
		"StatelessAddressAutoConfig": parityValue(map[string]any{
			"IPv4AutoConfigEnabled": parityValue(item.StatelessAddressAutoConfig.IPv4AutoConfigEnabled),
			"IPv6AutoConfigEnabled": parityValue(item.StatelessAddressAutoConfig.IPv6AutoConfigEnabled),
		}),
		"StaticNameServers": networkStrings(item.StaticNameServers),
		"TeamMode":          parityValue(item.TeamMode),
		"UefiDevicePath":    parityValue(item.UefiDevicePath),
	}
}
func networkConfig(c *gofish.APIClient) any {
	response, err := c.Get("/redfish/v1/NetworkConfig")
	must(err, "network manifest")
	defer schemas.DeferredCleanupHTTPResponse(response)
	var manifest struct {
		Cases []struct{ ID, URI, Kind string }
	}
	must(json.NewDecoder(response.Body).Decode(&manifest), "network manifest JSON")
	out := map[string]any{}
	for _, probe := range manifest.Cases {
		var value any
		var err error
		if probe.Kind == "collection" {
			var system *schemas.ComputerSystem
			system, err = schemas.GetComputerSystem(c, probe.URI)
			must(err, "network fixture owner")
			var items []*schemas.EthernetInterface
			items, err = system.EthernetInterfaces()
			values := []any{}
			for _, item := range items {
				values = append(values, networkProjection(item))
			}
			value = values
		} else {
			var item *schemas.EthernetInterface
			item, err = schemas.GetEthernetInterface(c, probe.URI)
			if err == nil {
				value = networkProjection(item)
			}
		}
		out[probe.ID] = map[string]any{"ok": err == nil, "error": parityError(err), "value": value}
	}
	return map[string]any{"cases": out}
}
