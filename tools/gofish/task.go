// Typed synthetic task reads only; no TaskMonitor polling or control calls.
package main

import (
	"encoding/json"
	"github.com/stmcginnis/gofish"
	"github.com/stmcginnis/gofish/schemas"
)

func taskUint(n *uint) any {
	if n == nil {
		return map[string]any{"state": "nil"}
	}
	return parityValue(*n)
}
func taskMessage(item schemas.Message) any {
	return map[string]any{
		"Message":                  parityValue(item.Message),
		"MessageId":                parityValue(item.MessageID),
		"MessageSeverity":          parityValue(item.MessageSeverity),
		"Resolution":               parityValue(item.Resolution),
		"Severity":                 parityValue(item.Severity),
		"UserAuthenticationSource": parityValue(item.UserAuthenticationSource),
		"Username":                 parityValue(item.Username),
		"MessageArgs":              bootStrings(item.MessageArgs),
		"RelatedProperties":        bootStrings(item.RelatedProperties),
	}
}
func taskMessages(items []schemas.Message) any {
	if items == nil {
		return map[string]any{"state": "nil"}
	}
	out := []any{}
	for _, item := range items {
		out = append(out, taskMessage(item))
	}
	return parityValue(out)
}
func taskTaskService(item *schemas.TaskService) any {
	return map[string]any{"uri": item.ODataID, "id": item.ID, "fields": map[string]any{
		"CompletedTaskOverWritePolicy":    parityValue(item.CompletedTaskOverWritePolicy),
		"DateTime":                        parityValue(item.DateTime),
		"LifeCycleEventOnTaskStateChange": parityValue(item.LifeCycleEventOnTaskStateChange),
		"ServiceEnabled":                  parityValue(item.ServiceEnabled),
		"TaskAutoDeleteTimeoutMinutes":    parityValue(item.TaskAutoDeleteTimeoutMinutes),
		"TaskMonitorAutoExpirySeconds":    taskUint(item.TaskMonitorAutoExpirySeconds),
		"Status":                          pcieHealth(item.Status),
	}}
}
func taskTask(item *schemas.Task) any {
	return map[string]any{"uri": item.ODataID, "id": item.ID, "fields": map[string]any{
		"EndTime":           parityValue(item.EndTime),
		"EstimatedDuration": parityValue(item.EstimatedDuration),
		"StartTime":         parityValue(item.StartTime),
		"TaskMonitor":       parityValue(item.TaskMonitor),
		"TaskState":         parityValue(item.TaskState),
		"TaskStatus":        parityValue(item.TaskStatus),
		"HidePayload":       parityValue(item.HidePayload),
		"PercentComplete":   taskUint(item.PercentComplete),
		"Messages":          taskMessages(item.Messages),
	}}
}
func taskEntity(item *schemas.Entity) any {
	return map[string]any{"uri": item.ODataID, "id": item.ID, "name": item.Name}
}
func taskInventory(c *gofish.APIClient) any {
	resp, err := c.Get("/redfish/v1/TaskTests")
	must(err, "task manifest")
	defer schemas.DeferredCleanupHTTPResponse(resp)
	var manifest struct {
		Cases []struct{ ID, URI, Kind string }
	}
	must(json.NewDecoder(resp.Body).Decode(&manifest), "task manifest JSON")
	out := map[string]any{}
	for _, probe := range manifest.Cases {
		var val any
		var err error
		switch probe.Kind {
		case "task_service":
			var root *gofish.Service
			root, err = schemas.GetObject[gofish.Service](c, probe.URI)
			if err == nil {
				var item *schemas.TaskService
				item, err = root.Tasks()
				if item == nil {
					val = map[string]any{"state": "nil"}
				} else {
					val = parityValue(taskTaskService(item))
				}
			}
		case "service", "tasks":
			var owner *schemas.TaskService
			owner, err = schemas.GetTaskService(c, probe.URI)
			if err == nil {
				if probe.Kind == "service" {
					val = taskTaskService(owner)
				} else {
					var items []*schemas.Task
					items, err = owner.Tasks()
					val = bootItems(items, taskTask)
				}
			}
		case "task", "sub_tasks", "created":
			var owner *schemas.Task
			owner, err = schemas.GetTask(c, probe.URI)
			if err == nil {
				switch probe.Kind {
				case "task":
					val = taskTask(owner)
				case "sub_tasks":
					var items []*schemas.Task
					items, err = owner.SubTasks()
					val = bootItems(items, taskTask)
				case "created":
					var items []*schemas.Entity
					items, err = owner.CreatedResources()
					val = bootItems(items, taskEntity)
				}
			}
		default:
			panic("invalid task operation")
		}
		out[probe.ID] = map[string]any{"ok": err == nil, "error": parityError(err), "value": val}
	}
	return map[string]any{"cases": out}
}
