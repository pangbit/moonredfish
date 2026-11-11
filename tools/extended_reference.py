"""Hash-pinned unchanged DMTF phase-two samples, never vendored into the package."""
import concurrent.futures
import hashlib
import urllib.request
from test_reference import BASE, COMMIT, FILES

# Only include resources reachable through advertised links. AC-RoT0 is an
# unreferenced upstream sample, so it is not a route in this discovery fixture.
EXTENDED_FILES = {
    "Managers/BMC/EthernetInterfaces/ToHost/index.json": "d0a789a6f3a7b6bddd8050ce2dcb9f329a4f540ae606beeab85e93105259e1cd",
    "Managers/BMC/EthernetInterfaces/eth0/index.json": "1872ca4605faef039404336a8b8a484d88f841755822eadf09aeeda434675435",
    "Managers/BMC/EthernetInterfaces/index.json": "dc4747477cc25c1e684d68a1ae87e5114375db821c36a44c2d3a887a37698ca1",
    "Managers/BMC/LogServices/Log/Entries/1/index.json": "2b7cccdb3dbfa218afa8734b0209c5e301625149b980f6f63b04949578727d8c",
    "Managers/BMC/LogServices/Log/Entries/index.json": "7498c44d6ff3e2bc0380e8c43bdda1bdd87cfd72564d45425f7a79df9011a72d",
    "Managers/BMC/LogServices/Log/index.json": "cf81f456c0ae744f9a019bf571dc5871d60eaa5a0c2fb34ba9223816e8e565b2",
    "Managers/BMC/LogServices/index.json": "d8244422cd4090da854a1a76b908eb155c6a5ff494aeaf3d13938f625826ddf0",
    "Systems/437XR1138R2/Bios/index.json": "9eafe8fa9720fe835e7eade042ea8bf890718773e5fd4da6cafa4ed87b2ff3ef",
    "Systems/437XR1138R2/EthernetInterfaces/12446A3B0411/index.json": "773e57798d8c821daefeff0559dbc895fc096ab91a29811695f87ea792a9b205",
    "Systems/437XR1138R2/EthernetInterfaces/12446A3B8890/index.json": "da0a4746d7c2de1404ef6d07250e3b6f22bed03a70070a7cca0109353778e65e",
    "Systems/437XR1138R2/EthernetInterfaces/ToManager/index.json": "473d926b174c4535e38ed96adab5007d4c0d2140f4c4729286abf12ae5903bde",
    "Systems/437XR1138R2/EthernetInterfaces/VLAN1/index.json": "190bc339da2e706253a8028a73cba98bb727c741be1fb88c7a8c1c2730487d5c",
    "Systems/437XR1138R2/EthernetInterfaces/index.json": "91b1f075f56dd1df358f79c65177c8eb548f240bc126b60287ef7dee16cd6cf5",
    "Systems/437XR1138R2/LogServices/Log1/Entries/1/index.json": "84bd7ba0bb44be62f8896ffa642e20905d785f34ca901860324b71189e1aa334",
    "Systems/437XR1138R2/LogServices/Log1/Entries/2/index.json": "0a8e728fdb77cc1dee27f4a82e10f870319d77de27e2169242e21470f6459150",
    "Systems/437XR1138R2/LogServices/Log1/Entries/index.json": "8afd34fcea9d79e780d276505006d2d9b4a325d37e7dc5774262be4a4869bc25",
    "Systems/437XR1138R2/LogServices/Log1/index.json": "d25b836ec58af9f87cbe598c8a3a5253b4c35ed60e43111a5daf780fb60f69d5",
    "Systems/437XR1138R2/LogServices/index.json": "78f77542aeefef925606b82a83dcdc054304ebd71151b34ec92c00817c78047c",
    "UpdateService/FirmwareInventory/BIOS/index.json": "4c3854e020df917c009e1cef7a9407f7a1ffbaec9d6168626371c0fc7ddd9371",
    "UpdateService/FirmwareInventory/BMC/index.json": "05aedcd24264ced6d8e8c5c86da27342ab1d87373240101f059124a916f3667b",
    "UpdateService/FirmwareInventory/SS/index.json": "59e64efb2fdb7a0d2b26d5d33460f7e79d30ff2b3884a693f87f3a88d28129ed",
    "UpdateService/FirmwareInventory/index.json": "f034f8f649bbd1ad94051633ad97faadbe998954c24fca65bb009e254037d438",
    "UpdateService/index.json": "1258be52529c78429bdcc143e3717d0402d837d98232d13a2af9d6149d34b004"
}


def load_extended_routes():
    def fetch(item):
        name, digest = item
        with urllib.request.urlopen(BASE + name, timeout=20) as response:
            data = response.read(65537)
        if len(data) > 65536 or hashlib.sha256(data).hexdigest() != digest:
            raise RuntimeError(f"pinned extended mockup integrity check failed: {name}")
        suffix = name.removesuffix("index.json").rstrip("/")
        return "/redfish/v1/" + suffix if suffix else "/redfish/v1/", data

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        return dict(pool.map(fetch, (FILES | EXTENDED_FILES).items()))
