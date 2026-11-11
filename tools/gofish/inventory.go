// Selected typed hardware fields only; never dump raw responses or OEM data.
package main

import (
	"github.com/stmcginnis/gofish"
	"github.com/stmcginnis/gofish/schemas"
)

type hardwareRecord = map[string]any

func hardwareBase(uri, id, name string, status schemas.Status) hardwareRecord {
	return hardwareRecord{"uri": uri, "id": id, "name": name, "status": map[string]any{
		"state": status.State, "health": status.Health, "health_rollup": status.HealthRollup,
	}}
}

func embeddedBase(uri, memberID, name string, status schemas.Status) hardwareRecord {
	r := hardwareBase(uri, "", name, status)
	delete(r, "id")
	r["member_id"] = memberID
	return r
}

func hardware(c *gofish.APIClient) any {
	out := map[string][]hardwareRecord{}
	for _, key := range []string{"systems", "chassis", "managers", "processors", "memory", "temperatures", "fans", "power_supplies", "power_control", "sensors", "thermal_fans", "modern_power_supplies"} {
		out[key] = []hardwareRecord{}
	}
	systems, err := c.Service.Systems()
	must(err, "hardware systems")
	for _, s := range systems {
		r := hardwareBase(s.ODataID, s.ID, s.Name, s.Status)
		r["manufacturer"], r["model"], r["serial_number"], r["part_number"], r["asset_tag"] = s.Manufacturer, s.Model, s.SerialNumber, s.PartNumber, s.AssetTag
		r["uuid"] = s.UUID
		r["bios_version"], r["hostname"], r["power"] = s.BiosVersion, s.HostName, s.PowerState
		r["processor_count"], r["memory_gib"] = s.ProcessorSummary.Count, s.MemorySummary.TotalSystemMemoryGiB
		out["systems"] = append(out["systems"], r)
		processors, err := s.Processors()
		must(err, "processors")
		for _, p := range processors {
			r := hardwareBase(p.ODataID, p.ID, p.Name, p.Status)
			r["manufacturer"], r["model"], r["processor_type"], r["instruction_set"] = p.Manufacturer, p.Model, p.ProcessorType, p.InstructionSet
			r["socket"], r["architecture"] = p.Socket, p.ProcessorArchitecture
			r["total_cores"], r["total_threads"], r["max_speed_mhz"] = p.TotalCores, p.TotalThreads, p.MaxSpeedMHz
			out["processors"] = append(out["processors"], r)
		}
		memory, err := s.Memory()
		must(err, "memory")
		for _, m := range memory {
			r := hardwareBase(m.ODataID, m.ID, m.Name, m.Status)
			r["manufacturer"], r["serial_number"], r["part_number"] = m.Manufacturer, m.SerialNumber, m.PartNumber
			r["capacity_mib"], r["memory_device_type"], r["operating_speed_mhz"] = m.CapacityMiB, m.MemoryDeviceType, m.OperatingSpeedMhz
			out["memory"] = append(out["memory"], r)
		}
	}
	chassis, err := c.Service.Chassis()
	must(err, "hardware chassis")
	for _, ch := range chassis {
		r := hardwareBase(ch.ODataID, ch.ID, ch.Name, ch.Status)
		r["manufacturer"], r["model"], r["serial_number"], r["part_number"], r["asset_tag"] = ch.Manufacturer, ch.Model, ch.SerialNumber, ch.PartNumber, ch.AssetTag
		r["uuid"] = ch.UUID
		r["chassis_type"], r["power"] = ch.ChassisType, ch.PowerState
		out["chassis"] = append(out["chassis"], r)
		thermal, err := ch.Thermal()
		must(err, "thermal")
		if thermal != nil {
			for _, t := range thermal.Temperatures {
				r := embeddedBase(t.ODataID, t.MemberID, t.Name, t.Status)
				r["reading_celsius"], r["upper_threshold_critical"] = t.ReadingCelsius, t.UpperThresholdCritical
				out["temperatures"] = append(out["temperatures"], r)
			}
			for _, f := range thermal.Fans {
				r := embeddedBase(f.ODataID, f.MemberID, f.Name, f.Status)
				r["reading"], r["reading_units"] = f.Reading, f.ReadingUnits
				out["fans"] = append(out["fans"], r)
			}
		}
		power, err := ch.Power()
		must(err, "power")
		if power != nil {
			for _, p := range power.PowerSupplies {
				r := embeddedBase(p.ODataID, p.MemberID, p.Name, p.Status)
				r["manufacturer"], r["model"], r["serial_number"], r["part_number"] = p.Manufacturer, p.Model, p.SerialNumber, p.PartNumber
				r["power_capacity_watts"], r["line_input_voltage"] = p.PowerCapacityWatts, p.LineInputVoltage
				out["power_supplies"] = append(out["power_supplies"], r)
			}
			for _, p := range power.PowerControl {
				r := embeddedBase(p.ODataID, p.MemberID, p.Name, p.Status)
				r["power_consumed_watts"], r["power_capacity_watts"] = p.PowerConsumedWatts, p.PowerCapacityWatts
				out["power_control"] = append(out["power_control"], r)
			}
		}
		// The bounded upstream comparison follows traditional links. The separate
		// synthetic modern fixture intentionally omits both legacy links.
		if thermal == nil && power == nil {
			sensors, err := ch.Sensors()
			must(err, "sensors")
			for _, s := range sensors {
				r := hardwareBase(s.ODataID, s.ID, s.Name, s.Status)
				r["reading"], r["reading_units"], r["reading_type"] = s.Reading, s.ReadingUnits, s.ReadingType
				out["sensors"] = append(out["sensors"], r)
			}
			ts, err := ch.ThermalSubsystem()
			must(err, "thermal subsystem")
			if ts != nil {
				fans, err := ts.Fans()
				must(err, "modern fans")
				for _, link := range fans {
					// v0.27.0's subsystem accessor returns the legacy ThermalFan type.
					// Re-fetch into the modern Fan type to exercise SpeedPercent faithfully.
					f, err := schemas.GetFan(c, link.ODataID)
					must(err, "modern fan")
					r := hardwareBase(f.ODataID, f.ID, f.Name, f.Status)
					r["speed_percent"] = f.SpeedPercent.Reading
					out["thermal_fans"] = append(out["thermal_fans"], r)
				}
			}
			ps, err := ch.PowerSubsystem()
			must(err, "power subsystem")
			if ps != nil {
				supplies, err := ps.PowerSupplies()
				must(err, "modern supplies")
				for _, link := range supplies {
					p, err := schemas.GetPowerSupplyUnit(c, link.ODataID)
					must(err, "modern supply")
					r := hardwareBase(p.ODataID, p.ID, p.Name, p.Status)
					r["manufacturer"], r["model"], r["serial_number"], r["part_number"] = p.Manufacturer, p.Model, p.SerialNumber, p.PartNumber
					r["power_capacity_watts"] = p.PowerCapacityWatts
					out["modern_power_supplies"] = append(out["modern_power_supplies"], r)
				}
			}
		}
	}
	managers, err := c.Service.Managers()
	must(err, "hardware managers")
	for _, m := range managers {
		r := hardwareBase(m.ODataID, m.ID, m.Name, m.Status)
		r["uuid"] = m.UUID
		r["model"], r["firmware_version"], r["manager_type"], r["power"] = m.Model, m.FirmwareVersion, m.ManagerType, m.PowerState
		out["managers"] = append(out["managers"], r)
	}
	return out
}
