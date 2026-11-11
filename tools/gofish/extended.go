// Test-only typed GoFish projections for phase-two reads.
package main

import (
	"github.com/stmcginnis/gofish"
	"github.com/stmcginnis/gofish/schemas"
)

func extendedStorage(item *schemas.Storage) map[string]any {
	out := hardwareBase(item.ODataID, item.ID, item.Name, item.Status)
	return out
}

func extendedDrive(item *schemas.Drive) map[string]any {
	out := hardwareBase(item.ODataID, item.ID, item.Name, item.Status)
	out["manufacturer"] = item.Manufacturer
	out["model"] = item.Model
	out["serial_number"] = item.SerialNumber
	out["part_number"] = item.PartNumber
	out["revision"] = item.Revision
	out["protocol"] = item.Protocol
	out["media_type"] = item.MediaType
	out["capacity_bytes"] = item.CapacityBytes
	out["failure_predicted"] = item.FailurePredicted
	return out
}

func extendedVolume(item *schemas.Volume) map[string]any {
	out := hardwareBase(item.ODataID, item.ID, item.Name, item.Status)
	out["capacity_bytes"] = item.CapacityBytes
	out["volume_type"] = item.VolumeType
	out["raid_type"] = item.RAIDType
	return out
}

func extendedEthernetInterface(item *schemas.EthernetInterface) map[string]any {
	out := hardwareBase(item.ODataID, item.ID, item.Name, item.Status)
	out["mac_address"] = item.MACAddress
	out["permanent_mac_address"] = item.PermanentMACAddress
	out["hostname"] = item.HostName
	out["fqdn"] = item.FQDN
	out["interface_enabled"] = item.InterfaceEnabled
	out["speed_mbps"] = item.SpeedMbps
	out["full_duplex"] = item.FullDuplex
	out["link_status"] = item.LinkStatus
	return out
}

func extendedNetworkAdapter(item *schemas.NetworkAdapter) map[string]any {
	out := hardwareBase(item.ODataID, item.ID, item.Name, item.Status)
	out["manufacturer"] = item.Manufacturer
	out["model"] = item.Model
	out["serial_number"] = item.SerialNumber
	out["part_number"] = item.PartNumber
	return out
}

func extendedLogService(item *schemas.LogService) map[string]any {
	out := hardwareBase(item.ODataID, item.ID, item.Name, item.Status)
	out["date_time"] = item.DateTime
	out["service_enabled"] = item.ServiceEnabled
	out["max_number_of_records"] = item.MaxNumberOfRecords
	out["over_write_policy"] = item.OverWritePolicy
	return out
}

func extendedLogEntry(item *schemas.LogEntry) map[string]any {
	out := map[string]any{"uri": item.ODataID, "id": item.ID, "name": item.Name}
	out["entry_type"] = item.EntryType
	out["severity"] = item.Severity
	out["created"] = item.Created
	out["message"] = item.Message
	out["message_id"] = item.MessageID
	out["message_args"] = item.MessageArgs
	return out
}

func extendedSoftwareInventory(item *schemas.SoftwareInventory) map[string]any {
	out := hardwareBase(item.ODataID, item.ID, item.Name, item.Status)
	out["version"] = item.Version
	out["software_id"] = item.SoftwareID
	out["manufacturer"] = item.Manufacturer
	out["lowest_supported_version"] = item.LowestSupportedVersion
	out["updateable"] = item.Updateable
	return out
}

func extendedBios(item *schemas.Bios) map[string]any {
	out := map[string]any{"uri": item.ODataID, "id": item.ID, "name": item.Name}
	out["attribute_registry"] = item.AttributeRegistry
	out["attributes"] = item.Attributes
	return out
}

func extended(c *gofish.APIClient) any {
	out := map[string][]map[string]any{
		"storage":             {},
		"drives":              {},
		"volumes":             {},
		"ethernet_interfaces": {},
		"network_adapters":    {},
		"log_services":        {},
		"log_entries":         {},
		"firmware_inventory":  {},
		"bios":                {},
	}
	systems, err := c.Service.Systems()
	must(err, "extended systems")
	for _, system := range systems {
		storage, err := system.Storage()
		must(err, "storage")
		for _, s := range storage {
			out["storage"] = append(out["storage"], extendedStorage(s))
			drives, err := s.Drives()
			must(err, "drives")
			for _, d := range drives {
				out["drives"] = append(out["drives"], extendedDrive(d))
			}
			volumes, err := s.Volumes()
			must(err, "volumes")
			for _, v := range volumes {
				out["volumes"] = append(out["volumes"], extendedVolume(v))
			}
		}
		interfaces, err := system.EthernetInterfaces()
		must(err, "system interfaces")
		for _, n := range interfaces {
			out["ethernet_interfaces"] = append(out["ethernet_interfaces"], extendedEthernetInterface(n))
		}
		bios, err := system.Bios()
		must(err, "BIOS")
		if bios != nil {
			out["bios"] = append(out["bios"], extendedBios(bios))
		}
		logs, err := system.LogServices()
		must(err, "system logs")
		extendedLogs(c, out, logs)
	}
	managers, err := c.Service.Managers()
	must(err, "extended managers")
	for _, manager := range managers {
		interfaces, err := manager.EthernetInterfaces()
		must(err, "manager interfaces")
		for _, n := range interfaces {
			out["ethernet_interfaces"] = append(out["ethernet_interfaces"], extendedEthernetInterface(n))
		}
		logs, err := manager.LogServices()
		must(err, "manager logs")
		extendedLogs(c, out, logs)
	}
	chassis, err := c.Service.Chassis()
	must(err, "extended chassis")
	for _, ch := range chassis {
		adapters, err := ch.NetworkAdapters()
		must(err, "network adapters")
		for _, n := range adapters {
			out["network_adapters"] = append(out["network_adapters"], extendedNetworkAdapter(n))
		}
		logs, err := ch.LogServices()
		must(err, "chassis logs")
		extendedLogs(c, out, logs)
	}
	update, err := c.Service.UpdateService()
	must(err, "update service")
	if update != nil {
		firmware, err := update.FirmwareInventory()
		must(err, "firmware inventory")
		for _, f := range firmware {
			out["firmware_inventory"] = append(out["firmware_inventory"], extendedSoftwareInventory(f))
		}
	}
	return out
}

func extendedLogs(c *gofish.APIClient, out map[string][]map[string]any, logs []*schemas.LogService) {
	for _, log := range logs {
		out["log_services"] = append(out["log_services"], extendedLogService(log))
		entries, err := log.Entries()
		must(err, "log entries")
		for _, link := range entries {
			// DMTF collections embed entries; explicitly compare the same member GET
			// bytes as moonredfish through GoFish's typed API. Not a request-count test.
			entry, err := schemas.GetLogEntry(c, link.ODataID)
			must(err, "log entry")
			out["log_entries"] = append(out["log_entries"], extendedLogEntry(entry))
		}
	}
}
