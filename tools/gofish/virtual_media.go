// Synthetic virtual media reads only; no image fetch, insertion or ejection.
package main

import (
	"encoding/json"
	"github.com/stmcginnis/gofish"
	"github.com/stmcginnis/gofish/schemas"
)

func virtualMediaBool(v *bool) any {
	if v == nil {
		return map[string]any{"state": "nil"}
	}
	return parityValue(*v)
}
func virtualMediaJSON(item *schemas.VirtualMedia) any {
	return map[string]any{"uri": item.ODataID, "id": item.ID, "fields": map[string]any{
		"ConnectedVia":         parityValue(item.ConnectedVia),
		"EjectPolicy":          parityValue(item.EjectPolicy),
		"EjectTimeout":         parityValue(item.EjectTimeout),
		"Image":                parityValue(item.Image),
		"ImageName":            parityValue(item.ImageName),
		"MediaType":            parityValue(item.MediaType),
		"TransferMethod":       parityValue(item.TransferMethod),
		"TransferProtocolType": parityValue(item.TransferProtocolType),
		"UserName":             parityValue(item.UserName),
		"Inserted":             virtualMediaBool(item.Inserted),
		"VerifyCertificate":    parityValue(item.VerifyCertificate),
		"WriteProtected":       virtualMediaBool(item.WriteProtected),
		"MediaTypes":           bootStrings(item.MediaTypes),
		"Status":               pcieHealth(item.Status),
		"SupportsMediaEject":   item.SupportsMediaEject,
		"SupportsMediaInsert":  item.SupportsMediaInsert,
	}}
}
func virtualMediaInventory(c *gofish.APIClient) any {
	resp, err := c.Get("/redfish/v1/VirtualMediaTests")
	must(err, "virtual media manifest")
	defer schemas.DeferredCleanupHTTPResponse(resp)
	var manifest struct {
		Cases []struct{ ID, URI, Kind string }
	}
	must(json.NewDecoder(resp.Body).Decode(&manifest), "virtual media manifest JSON")
	out := map[string]any{}
	for _, probe := range manifest.Cases {
		var val any
		var err error
		switch probe.Kind {
		case "media", "server_certificates", "client_certificates":
			var owner *schemas.VirtualMedia
			owner, err = schemas.GetVirtualMedia(c, probe.URI)
			if err == nil {
				if probe.Kind == "media" {
					val = virtualMediaJSON(owner)
				} else {
					var items []*schemas.Certificate
					if probe.Kind == "server_certificates" {
						items, err = owner.Certificates()
					} else {
						items, err = owner.ClientCertificates()
					}
					val = bootItems(items, certificateJSON)
				}
			}
		case "system_media":
			var owner *schemas.ComputerSystem
			owner, err = schemas.GetComputerSystem(c, probe.URI)
			if err == nil {
				var items []*schemas.VirtualMedia
				items, err = owner.VirtualMedia()
				val = bootItems(items, virtualMediaJSON)
			}
		case "manager_media":
			var owner *schemas.Manager
			owner, err = schemas.GetManager(c, probe.URI)
			if err == nil {
				var items []*schemas.VirtualMedia
				items, err = owner.VirtualMedia()
				val = bootItems(items, virtualMediaJSON)
			}
		default:
			panic("invalid virtual media operation")
		}
		out[probe.ID] = map[string]any{"ok": err == nil, "error": parityError(err), "value": val}
	}
	return map[string]any{"cases": out}
}
