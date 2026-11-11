"""Small synthetic phase-two graph and independent raw input projections.

No captured device data. Expectations are not derived from either client.
"""
import json

ROOT = "/redfish/v1"
FIELDS = {
    "storage": {},
    "drives": {"manufacturer": "Manufacturer", "model": "Model", "serial_number": "SerialNumber", "part_number": "PartNumber", "revision": "Revision", "protocol": "Protocol", "media_type": "MediaType", "capacity_bytes": "CapacityBytes", "failure_predicted": "FailurePredicted"},
    "volumes": {"capacity_bytes": "CapacityBytes", "volume_type": "VolumeType", "raid_type": "RAIDType"},
    "ethernet_interfaces": {"mac_address": "MACAddress", "permanent_mac_address": "PermanentMACAddress", "hostname": "HostName", "fqdn": "FQDN", "interface_enabled": "InterfaceEnabled", "speed_mbps": "SpeedMbps", "full_duplex": "FullDuplex", "link_status": "LinkStatus"},
    "network_adapters": {"manufacturer": "Manufacturer", "model": "Model", "serial_number": "SerialNumber", "part_number": "PartNumber"},
    "log_services": {"date_time": "DateTime", "service_enabled": "ServiceEnabled", "max_number_of_records": "MaxNumberOfRecords", "over_write_policy": "OverWritePolicy"},
    "log_entries": {"entry_type": "EntryType", "severity": "Severity", "created": "Created", "message": "Message", "message_id": "MessageId", "message_args": "MessageArgs"},
    "firmware_inventory": {"version": "Version", "software_id": "SoftwareId", "manufacturer": "Manufacturer", "lowest_supported_version": "LowestSupportedVersion", "updateable": "Updateable"},
    "bios": {"attribute_registry": "AttributeRegistry", "attributes": "Attributes"},
}


def extended_expected(routes):
    raw = {uri: json.loads(value) if isinstance(value, bytes) else value for uri, value in routes.items()}
    out = {kind: [] for kind in FIELDS}

    def linked(resource, key):
        link = (resource.get(key) or {}).get("@odata.id")
        return raw[link] if link else None

    def members(resource, key):
        page = linked(resource, key)
        result, seen = [], set()
        while page is not None:
            for item in page["Members"]:
                uri = item["@odata.id"]
                if uri not in seen:
                    seen.add(uri)
                    result.append(raw[uri])
            page = raw.get(page.get("Members@odata.nextLink"))
        return result

    def add(kind, r):
        fields = {"uri": "@odata.id", "id": "Id", "name": "Name", **FIELDS[kind]}
        item = {k: r[v] for k, v in fields.items() if r.get(v) is not None}
        if kind not in ("bios", "log_entries") and r.get("Status"):
            item["status"] = {k: r["Status"][v] for k, v in {"state": "State", "health": "Health", "health_rollup": "HealthRollup"}.items() if r["Status"].get(v) is not None}
        out[kind].append(item)

    root = raw[ROOT + "/"]
    for kind in ("Systems", "Managers", "Chassis"):
        for owner in members(root, kind):
            if kind == "Systems":
                for storage in members(owner, "Storage"):
                    add("storage", storage)
                    for link in storage.get("Drives", []):
                        add("drives", raw[link["@odata.id"]])
                    for volume in members(storage, "Volumes"):
                        add("volumes", volume)
                bios = linked(owner, "Bios")
                if bios is not None:
                    add("bios", bios)
            if kind in ("Systems", "Managers"):
                for interface in members(owner, "EthernetInterfaces"):
                    add("ethernet_interfaces", interface)
            if kind == "Chassis":
                for adapter in members(owner, "NetworkAdapters"):
                    add("network_adapters", adapter)
            for log in members(owner, "LogServices"):
                add("log_services", log)
                for entry in members(log, "Entries"):
                    add("log_entries", entry)
    update = linked(root, "UpdateService")
    if update is not None:
        for item in members(update, "FirmwareInventory"):
            add("firmware_inventory", item)
    return {kind: sorted(items, key=lambda item: item["uri"]) for kind, items in out.items()}


def extended_routes():
    routes = {}
    status = {"State": "Enabled", "Health": "OK", "HealthRollup": "OK"}

    def resource(uri, schema, **fields):
        routes[uri] = {"@odata.id": uri, "@odata.type": f"#{schema}.v1_0_0.{schema}", "Id": uri.rsplit("/", 1)[-1], "Name": "Synthetic " + schema, **fields}
        return {"@odata.id": uri}

    def collection(uri, items):
        routes[uri] = {"@odata.id": uri, "Members": items, "Members@odata.count": len(items)}
        return {"@odata.id": uri}

    s, ch, ma = (ROOT + "/" + family + "/Synthetic" for family in ("Systems", "Chassis", "Managers"))
    drive = resource(ch + "/Drives/0", "Drive", Manufacturer="Synthetic", Model="Synthetic SSD", SerialNumber="synthetic-drive", PartNumber="synthetic-part", Revision="test", Protocol="NVMe", MediaType="SSD", CapacityBytes=1099511627776, FailurePredicted=False, Status=status)
    volume = resource(s + "/Storage/0/Volumes/0", "Volume", CapacityBytes=0, VolumeType="RawDevice", RAIDType="None", Status=status)
    storage = resource(s + "/Storage/0", "Storage", Drives=[drive], Volumes=collection(s + "/Storage/0/Volumes", [volume]), Status=status)
    interface = resource(s + "/EthernetInterfaces/0", "EthernetInterface", MACAddress="02:00:00:00:00:01", PermanentMACAddress="02:00:00:00:00:01", HostName="synthetic", FQDN="synthetic.example.invalid", InterfaceEnabled=False, FullDuplex=True, SpeedMbps=0, LinkStatus="LinkDown", Status=status)
    bios = resource(s + "/Bios", "Bios", AttributeRegistry="Synthetic", Attributes={"BootMode": "Uefi", "Retries": 0, "Enabled": False})
    system = resource(s, "ComputerSystem", Storage=collection(s + "/Storage", [storage]), EthernetInterfaces=collection(s + "/EthernetInterfaces", [interface]), Bios=bios)
    adapter = resource(ch + "/NetworkAdapters/0", "NetworkAdapter", Manufacturer="Synthetic", Model="Synthetic NIC", SerialNumber="synthetic-nic", PartNumber="synthetic-nic-part", Status=status)
    chassis = resource(ch, "Chassis", NetworkAdapters=collection(ch + "/NetworkAdapters", [adapter]))
    logpath = ma + "/LogServices/0"
    entries = [resource(logpath + "/Entries/" + str(i), "LogEntry", EntryType="Event", Severity="OK", Created="2026-01-01T00:00:00Z", Message="Synthetic log text", MessageId="Synthetic.1.0.Event", MessageArgs=["synthetic-argument"]) for i in range(2)]
    entry_collection = collection(logpath + "/Entries", entries[:1])
    routes[logpath + "/Entries"]["Members@odata.nextLink"] = logpath + "/Entries?$skip=1"
    collection(logpath + "/Entries?$skip=1", entries[1:])
    log = resource(logpath, "LogService", DateTime="2026-01-01T00:00:00Z", ServiceEnabled=True, MaxNumberOfRecords=4096, OverWritePolicy="WrapsWhenFull", Entries=entry_collection, Status=status)
    manager = resource(ma, "Manager", LogServices=collection(ma + "/LogServices", [log]))
    firmware = resource(ROOT + "/UpdateService/FirmwareInventory/0", "SoftwareInventory", Version="synthetic-v1", SoftwareId="synthetic-fw", Manufacturer="Synthetic", LowestSupportedVersion="synthetic-v0", Updateable=False, Status=status)
    update = resource(ROOT + "/UpdateService", "UpdateService", FirmwareInventory=collection(ROOT + "/UpdateService/FirmwareInventory", [firmware]))
    routes[ROOT + "/"] = {"Id": "RootService", "Systems": collection(ROOT + "/Systems", [system]), "Chassis": collection(ROOT + "/Chassis", [chassis]), "Managers": collection(ROOT + "/Managers", [manager]), "UpdateService": update}
    return routes
