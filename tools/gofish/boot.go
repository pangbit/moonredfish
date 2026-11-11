// Typed boot inventory observations only. No key, boot or configuration actions.
package main

import (
	"encoding/json"

	"github.com/stmcginnis/gofish"
	"github.com/stmcginnis/gofish/schemas"
)

func bootString(s *string) any {
	if s == nil {
		return map[string]any{"state": "nil"}
	}
	return parityValue(*s)
}
func bootStrings[T ~string](items []T) any {
	if items == nil {
		return map[string]any{"state": "nil"}
	}
	return parityValue(items)
}
func bootJSON(item schemas.Boot) any {
	return parityValue(map[string]any{
		"AutomaticRetryConfig":         parityValue(item.AutomaticRetryConfig),
		"BootNext":                     parityValue(item.BootNext),
		"BootOrderPropertySelection":   parityValue(item.BootOrderPropertySelection),
		"BootSourceOverrideEnabled":    parityValue(item.BootSourceOverrideEnabled),
		"BootSourceOverrideMode":       parityValue(item.BootSourceOverrideMode),
		"BootSourceOverrideTarget":     parityValue(item.BootSourceOverrideTarget),
		"HttpBootUri":                  bootString(item.HTTPBootURI),
		"StopBootOnFault":              parityValue(item.StopBootOnFault),
		"TrustedModuleRequiredToBoot":  parityValue(item.TrustedModuleRequiredToBoot),
		"UefiTargetBootSourceOverride": parityValue(item.UefiTargetBootSourceOverride),
		"AliasBootOrder":               bootStrings(item.AliasBootOrder),
		"BootOrder":                    bootStrings(item.BootOrder),
		"BootSourceOverrideTarget@Redfish.AllowableValues":     bootStrings(item.AllowableBootSourceOverrideTargetValues),
		"UefiTargetBootSourceOverride@Redfish.AllowableValues": bootStrings(item.AllowableUefiTargetBootSourceOverrideValues),
	})
}
func bootBootOption(item *schemas.BootOption) any {
	return map[string]any{"uri": item.ODataID, "id": item.ID, "fields": map[string]any{
		"Alias":               parityValue(item.Alias),
		"BootOptionReference": parityValue(item.BootOptionReference),
		"DisplayName":         parityValue(item.DisplayName),
		"UefiDevicePath":      parityValue(item.UefiDevicePath),
		"BootOptionEnabled":   parityValue(item.BootOptionEnabled),
	}}
}
func bootSecureBoot(item *schemas.SecureBoot) any {
	return map[string]any{"uri": item.ODataID, "id": item.ID, "fields": map[string]any{
		"SecureBootCurrentBoot": parityValue(item.SecureBootCurrentBoot),
		"SecureBootMode":        parityValue(item.SecureBootMode),
		"SecureBootEnable":      parityValue(item.SecureBootEnable),
	}}
}
func bootSecureBootDatabase(item *schemas.SecureBootDatabase) any {
	return map[string]any{"uri": item.ODataID, "id": item.ID, "fields": map[string]any{
		"DatabaseId": parityValue(item.DatabaseID),
	}}
}
func bootSignature(item *schemas.Signature) any {
	return map[string]any{"uri": item.ODataID, "id": item.ID, "fields": map[string]any{
		"SignatureString":       parityValue(item.SignatureString),
		"SignatureType":         parityValue(item.SignatureType),
		"SignatureTypeRegistry": parityValue(item.SignatureTypeRegistry),
		"UefiSignatureOwner":    parityValue(item.UefiSignatureOwner),
	}}
}
func bootItems[T any](items []*T, project func(*T) any) any {
	if items == nil {
		return map[string]any{"state": "nil"}
	}
	out := []any{}
	for _, item := range items {
		out = append(out, project(item))
	}
	return parityValue(out)
}
func bootInventory(c *gofish.APIClient) any {
	resp, err := c.Get("/redfish/v1/BootTests")
	must(err, "boot manifest")
	defer schemas.DeferredCleanupHTTPResponse(resp)
	var manifest struct {
		Cases []struct{ ID, URI, Kind string }
	}
	must(json.NewDecoder(resp.Body).Decode(&manifest), "boot manifest JSON")
	out := map[string]any{}
	for _, probe := range manifest.Cases {
		var val any
		var err error
		switch probe.Kind {
		case "boot", "boot_metadata", "boot_options", "system_boot_options", "secure_boot":
			var owner *schemas.ComputerSystem
			owner, err = schemas.GetComputerSystem(c, probe.URI)
			if err == nil {
				switch probe.Kind {
				case "boot":
					val = bootJSON(owner.Boot)
				case "boot_metadata":
					var raw map[string]any
					must(json.Unmarshal(owner.RawData, &raw), "synthetic boot raw data")
					val = map[string]any{"boot": bootJSON(owner.Boot), "raw": raw, "boot_raw": raw["Boot"]}
				case "boot_options", "system_boot_options":
					var items []*schemas.BootOption
					if probe.Kind == "boot_options" {
						items, err = owner.Boot.BootOptions(c)
					} else {
						items, err = owner.BootOptions()
					}
					val = bootItems(items, bootBootOption)
				case "secure_boot":
					var item *schemas.SecureBoot
					item, err = owner.SecureBoot()
					if item == nil {
						val = map[string]any{"state": "nil"}
					} else {
						val = parityValue(bootSecureBoot(item))
					}
				}
			}
		case "option":
			var item *schemas.BootOption
			item, err = schemas.GetBootOption(c, probe.URI)
			if err == nil {
				val = bootBootOption(item)
			}
		case "secure", "databases":
			var item *schemas.SecureBoot
			item, err = schemas.GetSecureBoot(c, probe.URI)
			if err == nil {
				if probe.Kind == "secure" {
					val = bootSecureBoot(item)
				} else {
					var items []*schemas.SecureBootDatabase
					items, err = item.SecureBootDatabases()
					val = bootItems(items, bootSecureBootDatabase)
				}
			}
		case "database", "signatures":
			var item *schemas.SecureBootDatabase
			item, err = schemas.GetSecureBootDatabase(c, probe.URI)
			if err == nil {
				if probe.Kind == "database" {
					val = bootSecureBootDatabase(item)
				} else {
					var items []*schemas.Signature
					items, err = item.Signatures()
					val = bootItems(items, bootSignature)
				}
			}
		case "signature":
			var item *schemas.Signature
			item, err = schemas.GetSignature(c, probe.URI)
			if err == nil {
				val = bootSignature(item)
			}
		default:
			panic("invalid boot operation")
		}
		out[probe.ID] = map[string]any{"ok": err == nil, "error": parityError(err), "value": val}
	}
	return map[string]any{"cases": out}
}
