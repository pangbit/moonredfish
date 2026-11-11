"""Independent raw-fixture projection and small synthetic modern hardware graph.

No GoFish output is used to derive expectations. Only defined, non-null selected
fields are compared: GoFish scalar defaults cannot establish absence semantics.
MoonBit's Missing/Null/Value contract is tested separately by its native tests.
"""
import json

ROOT = "/redfish/v1"
BASE = {"uri": "@odata.id", "id": "Id", "name": "Name"}
ASSET = {"manufacturer": "Manufacturer", "model": "Model", "serial_number": "SerialNumber", "part_number": "PartNumber"}
FIELDS = {
    "systems": {**ASSET, "uuid": "UUID", "asset_tag": "AssetTag", "bios_version": "BiosVersion", "hostname": "HostName", "power": "PowerState", "processor_count": "ProcessorSummary.Count", "memory_gib": "MemorySummary.TotalSystemMemoryGiB"},
    "chassis": {**ASSET, "uuid": "UUID", "asset_tag": "AssetTag", "chassis_type": "ChassisType", "power": "PowerState"},
    "managers": {"uuid": "UUID", "model": "Model", "firmware_version": "FirmwareVersion", "manager_type": "ManagerType", "power": "PowerState"},
    "processors": {"socket": "Socket", "architecture": "ProcessorArchitecture", "manufacturer": "Manufacturer", "model": "Model", "processor_type": "ProcessorType", "instruction_set": "InstructionSet", "total_cores": "TotalCores", "total_threads": "TotalThreads", "max_speed_mhz": "MaxSpeedMHz"},
    "memory": {"manufacturer": "Manufacturer", "serial_number": "SerialNumber", "part_number": "PartNumber", "capacity_mib": "CapacityMiB", "memory_device_type": "MemoryDeviceType", "operating_speed_mhz": "OperatingSpeedMhz"},
    "temperatures": {"reading_celsius": "ReadingCelsius", "upper_threshold_critical": "UpperThresholdCritical"},
    "fans": {"reading": "Reading", "reading_units": "ReadingUnits"},
    "power_supplies": {**ASSET, "power_capacity_watts": "PowerCapacityWatts", "line_input_voltage": "LineInputVoltage"},
    "power_control": {"power_consumed_watts": "PowerConsumedWatts", "power_capacity_watts": "PowerCapacityWatts"},
    "sensors": {"reading": "Reading", "reading_units": "ReadingUnits", "reading_type": "ReadingType"},
    "thermal_fans": {"speed_percent": "SpeedPercent.Reading"},
    "modern_power_supplies": {**ASSET, "power_capacity_watts": "PowerCapacityWatts"},
}
EMBEDDED = ("temperatures", "fans", "power_supplies", "power_control")


def defined(resource, fields):
    out = {}
    for key, path in fields.items():
        value = resource
        for part in path.split(".") if not path.startswith("@") else [path]:
            value = value.get(part) if isinstance(value, dict) else None
        if value is not None:
            out[key] = value
    return out


def project_hardware(resource, kind):
    base = {"uri": "@odata.id", "member_id": "MemberId", "name": "Name"} if kind in EMBEDDED else BASE
    out = defined(resource, base | FIELDS[kind])
    status = defined(resource.get("Status", {}), {"state": "State", "health": "Health", "health_rollup": "HealthRollup"})
    if status:
        out["status"] = status
    return out


def hardware_expected(routes):
    raw = {uri: json.loads(value) if isinstance(value, bytes) else value for uri, value in routes.items()}
    out = {kind: [] for kind in FIELDS}

    def linked(resource, key):
        link = resource.get(key, {}).get("@odata.id")
        return raw[link] if link else None

    def members(resource, key):
        collection = linked(resource, key)
        return [raw[item["@odata.id"]] for item in collection["Members"]] if collection else []

    def add(kind, resource):
        out[kind].append(project_hardware(resource, kind))

    root = raw[ROOT + "/"]
    for kind in ("systems", "chassis", "managers"):
        for resource in members(root, kind.capitalize()):
            add(kind, resource)
            if kind == "systems":
                for child_kind, key in (("processors", "Processors"), ("memory", "Memory")):
                    for child in members(resource, key):
                        add(child_kind, child)
            if kind == "chassis":
                thermal, power = linked(resource, "Thermal"), linked(resource, "Power")
                for container, key, child_kind in ((thermal, "Temperatures", "temperatures"), (thermal, "Fans", "fans"), (power, "PowerSupplies", "power_supplies"), (power, "PowerControl", "power_control")):
                    for child in (container or {}).get(key, []):
                        add(child_kind, child)
                if thermal is None and power is None:
                    for sensor in members(resource, "Sensors"):
                        add("sensors", sensor)
                    for link, key, child_kind in (("ThermalSubsystem", "Fans", "thermal_fans"), ("PowerSubsystem", "PowerSupplies", "modern_power_supplies")):
                        for child in members(linked(resource, link) or {}, key):
                            add(child_kind, child)
    return {kind: sorted(items, key=lambda item: item["uri"]) for kind, items in out.items()}


def assert_hardware(actual, expected, name):
    """Check exact kinds/counts/URIs, and every independently defined field."""
    assert set(actual) == set(expected), f"{name}: hardware kind mismatch"

    def selected_equal(value, wanted, path):
        if isinstance(wanted, dict):
            assert isinstance(value, dict), f"{name}: {path} is not an object"
            for key, item in wanted.items():
                assert key in value, f"{name}: missing {path}.{key}"
                selected_equal(value[key], item, path + "." + key)
        else:
            assert value == wanted, f"{name}: defined field mismatch at {path}"

    for kind, records in expected.items():
        items = sorted(actual[kind], key=lambda item: item["uri"])
        assert len(items) == len(records), f"{name}: {kind} count mismatch"
        for value, wanted in zip(items, records):
            selected_equal(value, wanted, kind)


def modern_routes():
    """Original synthetic data, no vendor capture or upstream content."""
    routes = {}
    enabled = {"State": "Enabled", "Health": "OK", "HealthRollup": "OK"}

    def resource(uri, schema, **fields):
        result = {"@odata.id": uri, "@odata.type": "#" + schema, "Id": uri.rsplit("/", 1)[-1], "Name": "Synthetic " + schema.split(".")[0], **fields}
        routes[uri] = result
        return {"@odata.id": uri}

    def collection(uri, members):
        routes[uri] = {"@odata.id": uri, "Members": members, "Members@odata.count": len(members)}
        return {"@odata.id": uri}

    ch = ROOT + "/Chassis/Synthetic"
    sensor = resource(ch + "/Sensors/Temperature", "Sensor.v1_0_0.Sensor", Reading=23.5, ReadingUnits="Cel", ReadingType="Temperature", Status=enabled)
    fan = resource(ch + "/ThermalSubsystem/Fans/Fan1", "Fan.v1_0_0.Fan", SpeedPercent={"Reading": 42.5}, Status=enabled)
    supply = resource(ch + "/PowerSubsystem/PowerSupplies/PSU1", "PowerSupply.v1_0_0.PowerSupply", Manufacturer="Synthetic", Model="Synthetic PSU", SerialNumber="synthetic-psu-1", PartNumber="synthetic-part-1", PowerCapacityWatts=750, Status=enabled)
    thermal = resource(ch + "/ThermalSubsystem", "ThermalSubsystem.v1_0_0.ThermalSubsystem", Fans=collection(ch + "/ThermalSubsystem/Fans", [fan]))
    power = resource(ch + "/PowerSubsystem", "PowerSubsystem.v1_0_0.PowerSubsystem", PowerSupplies=collection(ch + "/PowerSubsystem/PowerSupplies", [supply]))
    chassis = resource(ch, "Chassis.v1_0_0.Chassis", ChassisType="RackMount", Status=enabled, ThermalSubsystem=thermal, PowerSubsystem=power, Sensors=collection(ch + "/Sensors", [sensor]))
    routes[ROOT + "/"] = {"Id": "RootService", "Systems": collection(ROOT + "/Systems", []), "Managers": collection(ROOT + "/Managers", []), "Chassis": collection(ROOT + "/Chassis", [chassis])}
    return routes
