// Action metadata GETs and parameter selection only. No action execution.
package main

import (
	"encoding/json"
	"github.com/stmcginnis/gofish"
	"github.com/stmcginnis/gofish/schemas"
	"strings"
)

func actionParameterJSON(p schemas.ActionInfoParameter) any {
	return map[string]any{
		"Name":                       parityValue(p.Name),
		"DataType":                   parityValue(p.DataType),
		"DefaultValue":               parityValue(p.DefaultValue),
		"ObjectDataType":             parityValue(p.ObjectDataType),
		"AllowablePattern":           parityValue(p.AllowablePattern),
		"AllowableNumbers":           bootStrings(p.AllowableNumbers),
		"AllowableValueDescriptions": bootStrings(p.AllowableValueDescriptions),
		"AllowableValues":            bootStrings(p.AllowableValues),
		"NoDefaultValue":             parityValue(p.NoDefaultValue),
		"Required":                   parityValue(p.Required),
	}
}
func actionInfoJSON(info *schemas.ActionInfo) any {
	var parameters any = map[string]any{"state": "nil"}
	if info.Parameters != nil {
		values := make([]any, 0, len(info.Parameters))
		for _, p := range info.Parameters {
			values = append(values, actionParameterJSON(p))
		}
		parameters = parityValue(values)
	}
	return map[string]any{"uri": info.ODataID, "id": info.ID, "fields": map[string]any{"Parameters": parameters}}
}
func actionInfoError(err error) string {
	if err != nil {
		if strings.HasPrefix(err.Error(), "failed to find supported values of type ") {
			return "parameter_not_found"
		}
		if strings.Contains(err.Error(), "ActionInfo not supported") {
			return "unsupported"
		}
	}
	return parityError(err)
}
func actionInfoInventory(c *gofish.APIClient, manifestURI string) any {
	resp, err := c.Get(manifestURI)
	must(err, "action info manifest")
	defer schemas.DeferredCleanupHTTPResponse(resp)
	var manifest struct {
		Cases []struct{ ID, URI, Kind, Name, Type, Action string }
	}
	must(json.NewDecoder(resp.Body).Decode(&manifest), "action info manifest JSON")
	out := map[string]any{}
	for _, probe := range manifest.Cases {
		var val any
		var info *schemas.ActionInfo
		var err error
		switch probe.Kind {
		case "info", "query":
			info, err = schemas.GetActionInfo(c, probe.URI)
		case "system_reset":
			var owner *schemas.ComputerSystem
			owner, err = schemas.GetComputerSystem(c, probe.URI)
			if err == nil {
				info, err = owner.ResetActionInfo()
			}
		case "manager_reset":
			var owner *schemas.Manager
			owner, err = schemas.GetManager(c, probe.URI)
			if err == nil {
				info, err = owner.ResetActionInfo()
			}
		case "insert_info", "eject_info":
			var owner *schemas.VirtualMedia
			owner, err = schemas.GetVirtualMedia(c, probe.URI)
			if err == nil {
				if probe.Kind == "insert_info" {
					info, err = owner.InsertMediaActionInfo()
				} else {
					info, err = owner.EjectMediaActionInfo()
				}
			}
		default:
			panic("invalid action info operation")
		}
		if err == nil {
			if probe.Kind == "query" {
				var values []string
				values, err = info.GetParamValues(probe.Name, schemas.ParameterTypes(probe.Type))
				if err == nil {
					val = bootStrings(values)
				}
			} else if probe.Kind == "info" {
				val = actionInfoJSON(info)
			} else {
				val = parityValue(actionInfoJSON(info))
			}
		}
		out[probe.ID] = map[string]any{"ok": err == nil, "error": actionInfoError(err), "value": val}
	}
	return map[string]any{"cases": out}
}
