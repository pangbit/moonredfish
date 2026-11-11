// Synthetic typed PCIe read adapter; no Update or action API is used.
package main

import (
	"encoding/json"

	"github.com/stmcginnis/gofish"
	"github.com/stmcginnis/gofish/schemas"
)

func pcieInt(n *int) any {
	if n == nil {
		return map[string]any{"state": "nil"}
	}
	return parityValue(*n)
}
func pcieHealth(s schemas.Status) any {
	return parityValue(map[string]any{"State": parityValue(s.State), "Health": parityValue(s.Health), "HealthRollup": parityValue(s.HealthRollup)})
}
func pcieDevice(item *schemas.PCIeDevice) any {
	return map[string]any{"uri": item.ODataID, "id": item.ID, "fields": map[string]any{
		"AssetTag":                parityValue(item.AssetTag),
		"DeviceType":              parityValue(item.DeviceType),
		"FirmwareVersion":         parityValue(item.FirmwareVersion),
		"Manufacturer":            parityValue(item.Manufacturer),
		"Model":                   parityValue(item.Model),
		"PartNumber":              parityValue(item.PartNumber),
		"SKU":                     parityValue(item.SKU),
		"SerialNumber":            parityValue(item.SerialNumber),
		"SparePartNumber":         parityValue(item.SparePartNumber),
		"StagedVersion":           parityValue(item.StagedVersion),
		"UUID":                    parityValue(item.UUID),
		"LocationIndicatorActive": parityValue(item.LocationIndicatorActive),
		"ReadyToRemove":           parityValue(item.ReadyToRemove),
		"PCIeInterface": parityValue(map[string]any{
			"LanesInUse":  pcieInt(item.PCIeInterface.LanesInUse),
			"MaxLanes":    pcieInt(item.PCIeInterface.MaxLanes),
			"MaxPCIeType": parityValue(item.PCIeInterface.MaxPCIeType),
			"PCIeType":    parityValue(item.PCIeInterface.PCIeType),
		}),
		"Status": pcieHealth(item.Status),
	}}
}
func pcieFunction(item *schemas.PCIeFunction) any {
	return map[string]any{"uri": item.ODataID, "id": item.ID, "fields": map[string]any{
		"ARIFunctionNumber": parityValue(item.ARIFunctionNumber),
		"BusNumber":         parityValue(item.BusNumber),
		"ClassCode":         parityValue(item.ClassCode),
		"DeviceClass":       parityValue(item.DeviceClass),
		"DeviceId":          parityValue(item.DeviceID),
		"DeviceNumber":      parityValue(item.DeviceNumber),
		"FunctionNumber":    parityValue(item.FunctionNumber),
		"FunctionProtocol":  parityValue(item.FunctionProtocol),
		"FunctionType":      parityValue(item.FunctionType),
		"RevisionId":        parityValue(item.RevisionID),
		"SegmentNumber":     parityValue(item.SegmentNumber),
		"SubsystemId":       parityValue(item.SubsystemID),
		"SubsystemVendorId": parityValue(item.SubsystemVendorID),
		"VendorId":          parityValue(item.VendorID),
		"ARIModeEnabled":    parityValue(item.ARIModeEnabled),
		"Enabled":           parityValue(item.Enabled),
		"FunctionId":        pcieInt(item.FunctionID),
		"Status":            pcieHealth(item.Status),
	}}
}
func pcieItems[T any](items []*T, project func(*T) any) any {
	if items == nil {
		return map[string]any{"state": "nil"}
	}
	out := []any{}
	for _, item := range items {
		out = append(out, project(item))
	}
	return parityValue(out)
}
func pcie(c *gofish.APIClient) any {
	resp, err := c.Get("/redfish/v1/PCIeTests")
	must(err, "PCIe manifest")
	defer schemas.DeferredCleanupHTTPResponse(resp)
	var manifest struct {
		Cases []struct{ ID, URI, Kind string }
	}
	must(json.NewDecoder(resp.Body).Decode(&manifest), "PCIe manifest JSON")
	out := map[string]any{}
	for _, probe := range manifest.Cases {
		var val any
		var err error
		switch probe.Kind {
		case "device":
			var item *schemas.PCIeDevice
			item, err = schemas.GetPCIeDevice(c, probe.URI)
			if err == nil {
				val = pcieDevice(item)
			}
		case "function":
			var item *schemas.PCIeFunction
			item, err = schemas.GetPCIeFunction(c, probe.URI)
			if err == nil {
				val = pcieFunction(item)
			}
		case "system_devices", "system_functions":
			var owner *schemas.ComputerSystem
			owner, err = schemas.GetComputerSystem(c, probe.URI)
			if err == nil {
				if probe.Kind == "system_devices" {
					var items []*schemas.PCIeDevice
					items, err = owner.PCIeDevices()
					val = pcieItems(items, pcieDevice)
				} else {
					var items []*schemas.PCIeFunction
					items, err = owner.PCIeFunctions()
					val = pcieItems(items, pcieFunction)
				}
			}
		case "chassis_devices":
			var owner *schemas.Chassis
			owner, err = schemas.GetChassis(c, probe.URI)
			if err == nil {
				var items []*schemas.PCIeDevice
				items, err = owner.PCIeDevices()
				val = pcieItems(items, pcieDevice)
			}
		case "device_functions":
			var owner *schemas.PCIeDevice
			owner, err = schemas.GetPCIeDevice(c, probe.URI)
			if err == nil {
				var items []*schemas.PCIeFunction
				items, err = owner.PCIeFunctions()
				val = pcieItems(items, pcieFunction)
			}
		case "function_device":
			var owner *schemas.PCIeFunction
			owner, err = schemas.GetPCIeFunction(c, probe.URI)
			if err == nil {
				var item *schemas.PCIeDevice
				item, err = owner.PCIeDevice()
				if item == nil {
					val = map[string]any{"state": "nil"}
				} else {
					val = parityValue(pcieDevice(item))
				}
			}
		default:
			panic("invalid PCIe operation")
		}
		out[probe.ID] = map[string]any{"ok": err == nil, "error": parityError(err), "value": val}
	}
	return map[string]any{"cases": out}
}
