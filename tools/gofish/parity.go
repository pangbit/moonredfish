// Read-only differential observations. Defaults and partial results are retained.
package main

import (
	"encoding/json"
	"errors"
	"github.com/stmcginnis/gofish"
	"github.com/stmcginnis/gofish/schemas"
	"io"
)

func parityValue(value any) any { return map[string]any{"state": "value", "value": value} }
func parityError(err error) string {
	var syntax *json.SyntaxError
	var typed *json.UnmarshalTypeError
	var collection *schemas.CollectionError
	switch {
	case err == nil:
		return ""
	case errors.As(err, &collection):
		return "collection"
	case errors.Is(err, io.ErrUnexpectedEOF):
		return "json_eof"
	case errors.As(err, &syntax):
		return "json_syntax"
	case errors.As(err, &typed):
		return "json_type"
	case status(err) != 0:
		return "http"
	default:
		panic("unclassified synthetic GoFish error")
	}
}
func parity(c *gofish.APIClient) any {
	response, err := c.Get("/redfish/v1/Parity")
	must(err, "parity manifest")
	defer schemas.DeferredCleanupHTTPResponse(response)
	var manifest struct {
		Cases []struct{ ID, Kind, URI, Field string }
	}
	must(json.NewDecoder(response.Body).Decode(&manifest), "parity manifest JSON")
	out := map[string]any{}
	for _, test := range manifest.Cases {
		var value any
		var err error
		if test.Kind == "drive" {
			var item *schemas.Drive
			item, err = schemas.GetDrive(c, test.URI)
			if err == nil {
				switch test.Field {
				case "CapacityBytes":
					value = map[string]any{"state": "nil"}
					if item.CapacityBytes != nil {
						value = parityValue(*item.CapacityBytes)
					}
				case "FailurePredicted":
					value = parityValue(item.FailurePredicted)
				case "Protocol":
					value = parityValue(item.Protocol)
				case "SerialNumber":
					value = parityValue(item.SerialNumber)
				default:
					panic("unknown parity field")
				}
			}
		} else {
			var items []*schemas.ComputerSystem
			items, err = schemas.GetCollectionObjects[schemas.ComputerSystem](c, test.URI)
			members := []map[string]string{}
			for _, item := range items {
				members = append(members, map[string]string{"id": item.ID, "name": item.Name})
			}
			value = members
		}
		out[test.ID] = map[string]any{"ok": err == nil, "error": parityError(err), "value": value}
	}
	return map[string]any{"cases": out}
}
