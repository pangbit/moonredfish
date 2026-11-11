# Typed inventory / 类型化资产与健康信息

These APIs are **Unreleased source additions**, not part of the published Mooncakes
0.1.0. All device operations below are GETs. Authentication still creates and deletes
only this client's session. No physical BMC has been tested.

以下 API 是 **Unreleased 源码新增能力**，不属于已发布的 Mooncakes 0.1.0。
下列设备操作均为 GET；认证仍仅创建和删除客户端自己的会话。尚未验证真实 BMC。

## Read a resource / 读取资源

`systems()`, `chassis()` and `managers()` retain their existing `Array[Resource]`
return types. Call `resource.system_info()`, `.chassis_info()` or `.manager_info()`
for common asset, power and status properties. The views retain `resource`, including
its URI and original parsed `json`. They do not print or redact identifiers for you.
Use the view matching the resource you fetched: these are selected-field parsers,
not schema-version validators. Embedded Fan/PowerSupply entries retain `json`; standalone
modern resources additionally retain `resource: Some(original)`, including the request
URI even when the response omits `@odata.id`. Embedded entries use `resource: None`.

上述三种清单 API 保持原有返回类型。调用对应的类型化方法获取常用资产、电源及状态字段。
视图保留原始 `Resource`，包括 URI 和完整解析后 JSON；库不会代替应用输出或脱敏标识。
调用者应选用与资源对应的视图：这是选定字段解析器，不是 schema 版本验证器。
嵌入的 Fan/PowerSupply 保留 json；现代独立资源另保留 resource: Some(original)，即使
响应未给出 @odata.id 也能保留请求 URI。嵌入条目的 resource 为 None。

| View / 视图 | Selected data / 选定字段 |
| --- | --- |
| `SystemInfo` | Manufacturer, model, serial/part/asset tag, UUID, hostname, BIOS, power, processor count, total memory GiB, status / 厂商、型号、标识、BIOS、电源、处理器数量、总内存 GiB、状态 |
| `ChassisInfo` | Manufacturer, model, serial/part/asset tag, UUID when reported, chassis type, power, status / 厂商、型号、标识、报告时的 UUID、机箱类型、电源、状态 |
| `ManagerInfo` | Manufacturer, model, serial, UUID, manager type, firmware, power, status / 厂商、型号、标识、管理器类型、固件、电源、状态 |
| `Processor` | Socket, manufacturer, model, type, architecture, instruction set, core/thread count, maximum MHz, status / 插槽、厂商、型号、类型、架构、指令集、核/线程数、最大 MHz、状态 |
| `Memory` | Manufacturer, serial/part, locator, device type, capacity MiB, operating MHz, status / 厂商、标识、位置、设备类型、容量 MiB、运行 MHz、状态 |
| `Thermal` | Optional temperature and fan arrays / 可选温度与风扇数组 |
| `Power` | Optional supply and power-control arrays / 可选电源及功耗控制信息数组 |
| `Sensor` | Reading, reported units, reading type, status / 读数、报告单位、读数类型、状态 |

`Health` retains `State`, `Health`, and `HealthRollup` independently. A missing Health
is not OK; a State of Absent is not a zero measurement. Unknown strings are preserved
without mapping them to a guessed enum or an aggregate health judgement.

`Health` 分别保留三个状态字段。缺失 Health 不等于 OK，State 为 Absent 不等于测量值为零。
未知字符串原样保留，不猜测枚举或汇总健康结论。

## Missing, null and zero / 缺失、null 与零

Reported selected values use `Field[T]` (derived VirtualMedia action-advertisement flags
are plain Bool, described below):

- `Missing`: the property is absent.
- `Null`: the property, or a containing summary object, is explicit JSON null.
- `Value(value)`: a real value, including zero, an empty string or an empty array.

类型化字段使用上述三态，缺失、显式 null、真实值严格区分。嵌套摘要父对象为 null 时，
其选定字段返回 Null；父对象存在但子字段缺失则为 Missing。零、空字符串和空数组都是有效值。

`field.value()` intentionally collapses Missing and Null into `None` for applications
that do not need that distinction. Existing `Resource.id`, `.name`, `.resource_type`
and `.string()` keep their prior `Option` contract; inspect `resource.json` if their
missing/null distinction matters. Raw JSON also preserves OEM and unmodeled fields.

`value()` 是调用方主动选择的简化接口，会把 Missing 和 Null 合并为 None。既有 Resource
标识及字符串接口维持原 Option 契约，需区分时检查原始 JSON；OEM 和未建模字段也完整保留。

Malformed selected field types fail with `InvalidResponse`, not Missing. Numeric
readings must be finite. Counts are nonnegative Int32 integers. Measurements retain
reported units: legacy Celsius, RPM/Percent, watts, MiB/GiB and MHz are not silently
converted. Modern `Sensor.reading_units` retains the supplied unit string, and
`Fan.speed_percent.reading` is percent; it is not the legacy RPM `Fan.reading`.
This is not a complete range or cross-field schema validation.

选定字段类型错误会报错，不伪装成缺失。数值必须有限，数量为非负 Int32 整数。测量值
保留原单位，不悄然换算。现代 Sensor 保留服务端单位，Fan 的 SpeedPercent.Reading 是
百分比，不冒充传统风扇 Reading 的 RPM。本实现不执行完整范围或跨字段 schema 验证。

## Follow advertised links / 跟随显式链接

| Client method / 方法 | Owner / 来源 | Result inside `Field` / 三态内结果 |
| --- | --- | --- |
| `processors(system)` | ComputerSystem.Processors | `Array[Processor]` |
| `memory(system)` | ComputerSystem.Memory | `Array[Memory]` |
| `thermal(chassis)` | Chassis.Thermal | `Thermal` |
| `power(chassis)` | Chassis.Power | `Power` |
| `sensors(chassis)` | Chassis.Sensors | `Array[Sensor]` |
| `thermal_subsystem(chassis)` | Chassis.ThermalSubsystem | `Resource` |
| `power_subsystem(chassis)` | Chassis.PowerSubsystem | `Resource` |
| `fans(subsystem)` | ThermalSubsystem.Fans | `Array[Fan]` |
| `power_supplies(subsystem)` | PowerSubsystem.PowerSupplies | `Array[PowerSupply]` |

An absent/null link returns Missing/Null without a request; a successful empty collection
returns Value([]). Unsafe links, malformed collections, 403, 404 and failed member reads
raise errors. There is no guessed path, automatic fallback, partial collection result,
permission bypass or retry. Legacy and modern resources may coexist; callers can choose
either or both explicitly. The library does not combine readings or double-count them.

链接缺失/null 时不发请求；成功的空集合返回 Value([])。危险链接、畸形集合、403、404
和成员读取失败均报错。不猜路径、不自动回退、不返回不完整集合、不绕过权限、不自动重试。
新旧资源可共存，由调用方明确选择；库不自动合并读数或重复计数。

Each collection method shares the existing total-byte, unique-member, per-page and
operation-time budgets across its collection pages and member GETs. Each single linked
resource also obeys total-byte and operation-time budgets. Per-request timeout/body
limits, TLS verification and same-origin Redfish paths still apply. Budgets are per
method call, not for an application's entire multi-resource inventory. Embedded
Thermal/Power arrays are bounded by the response body limit, not `max_members`.

每个集合调用在分页和成员 GET 间共享既有累计字节、唯一成员数、页数和操作总时限。
单链接资源也遵守累计字节及操作时限；单请求时限、正文上限、TLS 和同源路径规则保持有效。
这些预算按方法调用计算，不覆盖应用自行串联的整次全资产扫描。嵌入数组受正文大小限制，
不使用集合成员数上限。

The modern subset covers Sensors, Fan SpeedPercent and PowerSupply asset/capacity/status
fields. PowerSupplyMetrics, thermal metrics, redundancy and other resource families
remain accessible as raw resources through validated links and `get()`; they are not
claimed as dedicated typed capabilities in this phase.

现代资源子集包含 Sensor、Fan 速度百分比及 PowerSupply 资产/容量/状态。
PowerSupplyMetrics、热指标、冗余和其他资源族仍可经安全链接及 get() 读取原始资源，
本阶段不宣称提供这些专门类型化能力。

## Runnable example / 可运行示例

```sh
# Safe offline default; synthetic data only / 默认离线，只有合成数据
moon run examples/hardware --target native

# Only for an authorized target / 仅限已授权目标
moon run examples/hardware --target native -- https://authorized-bmc.example.invalid
```

Without credentials, the HTTPS example reads anonymously. If authentication is needed,
provide both `REDFISH_USERNAME` and `REDFISH_PASSWORD` through a trusted launcher and,
optionally, `REDFISH_CA_FILE`. It uses `with_session`; failed cleanup remains an error.
It prints counts and missing/null states only, never serial numbers, UUIDs or raw JSON.
The example follows both advertised legacy and modern links; it does not infer that
one replaces the other. A denied advertised link stops the example rather than hiding
an incomplete inventory. Protect the launching environment and do not commit `.env`.

未提供凭据时匿名 HTTPS 读取；需要认证时由可信启动器提供两个凭据变量及可选 CA 文件。
使用 with_session，清理失败仍报错。示例只输出数量和缺失状态，不输出序列号、UUID 或
原始 JSON。新旧链接都被显式读取，不推断替代关系；已声明链接被拒绝时直接失败，避免
隐藏不完整清单。启动环境需要保护，不提交 .env。

## Verification boundary / 验证边界

Native tests cover three-state values, unknown enums, units and malformed fields.
The existing local HTTP/HTTPS suite checks linked pagination, deduplication, shared
budgets, absent/null/empty, 403/404, unsafe links and no partial results. The GoFish
comparison adds 18 unchanged hash-pinned DMTF files and a separate 13-route synthetic
modern graph. Both implementations are checked against independently extracted defined
fields. GoFish's zero defaults do not establish missing/null equivalence.

单测覆盖三态值、未知枚举、单位和畸形字段；本机 HTTP/HTTPS 测试覆盖新链接的分页、去重、
共享预算、缺失/null/空集合、错误与不返回部分结果。GoFish 对照使用 18 个固定哈希的
未修改 DMTF 文件，以及独立的 13 路由现代资源合成图；两端各自对照从原输入提取的有值字段。
GoFish 零值默认行为不用于证明缺失/null 语义相同。

See [REFERENCE.md](REFERENCE.md), [COMPARISON.md](COMPARISON.md) and
[ACCEPTANCE.md](ACCEPTANCE.md). This is selected interoperability evidence, not physical
BMC, vendor, complete Redfish/Swordfish or firmware compatibility certification.

来源、对照和验收边界见以上文档。这是选定子集互通证据，不是真实 BMC、厂商、完整
Redfish/Swordfish 或固件兼容性认证。

## Extended read-only inventory (Unreleased) / 扩展只读清单（未发布）

The second increment adds selected views, not a full schema graph:
第二批增加以下选定视图，不引入完整 schema 图或自动递归扫描：

| View / 视图 | Selected data / 选定字段 |
| --- | --- |
| `Storage`, `Drive`, `Volume` | Storage status; drive identity, protocol, media, capacity bytes, predicted failure; volume bytes, VolumeType and RAIDType / 存储状态；磁盘资产、协议、介质、字节容量、故障预测；卷容量及两个独立类型字段 |
| `EthernetInterface` | MAC addresses, hostname/FQDN, enabled, speed Mbps, duplex and link state / MAC、主机名、启用状态、Mbps 速率、双工和链路状态 |
| `NetworkAdapter` | Physical adapter manufacturer, model, serial/part and status / 物理适配器厂商、型号、序列号/部件号及状态 |
| `LogService`, `LogEntry` | Service status/capacity/overwrite metadata; entry type, severity, timestamp, message ID/text/arguments / 日志服务状态、容量及覆盖策略；条目类型、等级、时间、消息标识/正文/参数 |
| `SoftwareInventory` | Firmware version, software ID, manufacturer, minimum version, Updateable and status / 固件版本、软件标识、厂商、最低版本、可更新标记及状态 |
| `Bios` | AttributeRegistry string and current Attributes object / 属性注册表标识及当前属性对象 |

All views retain `resource` and raw JSON. `Field` preserves false, zero, empty arrays
and empty BIOS objects. Unknown enum strings remain unchanged. Boolean fields must
be JSON booleans, BIOS Attributes must be an object, and MessageArgs must be an array
of strings. BIOS attributes are not coerced to strings or classified as writable.
The number fields added here use nonnegative integral `Double` values capped at
9,007,199,254,740,991 (2^53−1); larger values fail instead of being exposed as a
rounded typed integer. This is a deliberately bounded selected-field decoder, not
full Redfish numeric/schema validation. Original parsed JSON is available for wider
application-specific handling. HTTP decoding preserves number spellings and checks exact
integrality before Double rounding; `1.0000000000000001` and `1e-9999` are rejected.
Mathematically integral `1.0` and `1e3` remain accepted. Caller-created Json that has already
lost its number spelling cannot recover discarded precision; parse external JSON with
`preserve_number_repr=true`. Raw JSON reserialization retains the preserved spelling.
Units are bytes and Mbps, with no conversion.

所有视图保留原资源及 JSON；false、零、空数组和空属性对象均是有效值。未知枚举原样保留。
布尔字段须为 JSON 布尔值，BIOS Attributes 须为对象，MessageArgs 须为字符串数组；
不把 BIOS 属性强制转换为字符串，也不推断写权限。新增数字字段使用非负整数 Double，
上限为 2^53−1；超过范围报错，不作为已四舍五入的类型化整数返回。这是有界字段解码，
不是完整数值或 schema 验证。HTTP 解码保留数字原文，在浮点舍入前校验整数性，拒绝
`1.0000000000000001`、`1e-9999`，继续接受数学上为整数的 `1.0`、`1e3`。
调用者的 Json 若已丢失原文则无法恢复精度；自行解析外部 JSON 时应启用
`preserve_number_repr=true`。raw JSON 再序列化保留数字拼写。单位为字节和 Mbps。

| Client method / 方法 | Explicit owner link / 显式来源链接 |
| --- | --- |
| `storage(system)` | ComputerSystem.Storage collection |
| `drives(storage.resource)` | Storage.Drives **array of links**, not a collection / 链接数组，不是集合 |
| `volumes(storage.resource)` | Storage.Volumes collection |
| `ethernet_interfaces(owner)` | ComputerSystem or Manager.EthernetInterfaces collection |
| `network_adapters(chassis)` | Chassis.NetworkAdapters collection |
| `log_services(owner)` | ComputerSystem, Chassis or Manager.LogServices collection |
| `log_entries(service.resource)` | LogService.Entries collection |
| `update_service(root)` | ServiceRoot.UpdateService resource |
| `firmware_inventory(update)` | UpdateService.FirmwareInventory collection |
| `bios(system)` | ComputerSystem.Bios resource |

Each method returns `Field` around its result. Collection methods return arrays of
matching views. `update_service` returns a Resource; `bios` returns a Bios view.
An advertised link is followed even if its path is unconventional. Missing/null
links do not trigger a guessed URI, a fallback to a different model, or a request.
Malformed links, 403/404 and failed member GETs fail the whole method.

各方法在结果外保留三态；集合返回对应视图数组，update_service 返回 Resource，bios
返回 Bios。遵循显式链接而非惯例路径；缺失/null 不猜路径、不切换模型、不发请求。
畸形链接、403/404、任一成员读取失败均使整个方法失败。

`drives` validates all supplied links, deduplicates them in first-seen order, and
checks `max_members` before any GET. Its member reads share one total-byte budget
and operation timeout. Collections such as log entries share those budgets across
all pages and member GETs, with page and unique-member limits. These APIs deliberately
do not fetch child collections recursively. A separate explicit method call starts
a new budget, just like the first-phase APIs; an application's entire multi-call
scan needs its own outer deadline/collection policy. No partial result is returned.

磁盘链接先全部验证、按首次出现顺序去重并检查成员上限，再开始 GET；所有成员共用累计
字节预算和操作时限。日志等集合的全部分页与成员 GET 也共享预算，同时受页数及唯一成员
上限约束。API 不自动递归读取子集合。与第一阶段相同，新的显式方法调用有独立预算；
应用若串联整次资产扫描，应另设外层截止时间及采集策略。单次方法不返回部分结果。

Storage and SimpleStorage are not merged. The latter, embedded storage controllers,
network ports/functions, IP address/VLAN models, update actions, BIOS SettingsObject
and attribute registries remain raw/unmodeled. `Updateable`, `InterfaceEnabled` and
log capability fields describe reported state, not authorization. Firmware update,
BIOS PATCH, log clearing, network changes and other controls are not implemented.

Storage 不与 SimpleStorage 合并；SimpleStorage、嵌入控制器、网络端口/功能、IP/VLAN
模型、更新动作、BIOS SettingsObject 和属性注册表尚无专用解析。Updateable 等标志是
设备报告状态，不代表当前账户权限。不实现固件更新、BIOS PATCH、清日志或网络修改。

```sh
moon run examples/extended --target native
# Authorized target only; same optional session environment as examples/hardware
# 仅限已授权目标；可选认证环境与 hardware 示例相同
moon run examples/extended --target native -- https://authorized-bmc.example.invalid
python3 tools/test_extended.py
```

The example defaults to offline synthetic resources. Its live mode prints counts
and missing/null/present markers only: never log messages, arguments, MACs, serials,
BIOS attributes or raw JSON. It reads current BIOS attributes, not pending settings.
Protect raw resources and log text as private data before sharing them.
示例默认离线；联网模式仅输出数量及缺失/null/存在状态，不输出日志正文、参数、MAC、
序列号、BIOS 属性或 JSON。只读当前 BIOS，不读待应用设置。分享前须审查和脱敏原始数据。

The comparison adds 23 hash-pinned, unchanged DMTF rack-mount files (30 including
baseline discovery) for Ethernet interfaces, logs, firmware and BIOS. The pinned
sample advertises SimpleStorage, not Storage, and lacks NetworkAdapters; a separate
26-route synthetic graph covers Storage/Drives/Volumes, NetworkAdapters, defined
fields in every new family and paginated logs. Each client is checked independently
against fields extracted from the original inputs. GoFish defaults do not prove
Missing/Null equivalence. Local mocks additionally test absent/null/empty links,
drive deduplication, malformed/unsafe links, 403/404 and shared traversal limits.

对照新增 23 个固定哈希、未修改的 DMTF 文件，连同基础发现共 30 个，覆盖网络接口、日志、
固件和 BIOS。该样例只有 SimpleStorage 而无 Storage，也没有 NetworkAdapters；独立的
26 路由合成图覆盖存储/磁盘/卷、适配器、所有新增资源的选定字段及日志分页。两个客户端
分别对照原始输入提取的字段，不以 GoFish 默认值证明三态语义等价。本机 mock 另测链接
三态/空值、磁盘去重、畸形/危险链接、403/404 及共享遍历预算。尚无真实 BMC 验证。


## Ethernet configuration reads (Unreleased) / 以太网配置读取（未发布）

`resource.ethernet_interface()` and `client.ethernet_interfaces(owner)` now expose
`dhcpv4`, `dhcpv6`, `stateless_address_auto_config`, `name_servers`,
`static_name_servers`, `auto_neg`, `ethernet_interface_type`, `ipv6_default_gateway`,
`ipv6_enabled`, `routing_scope`, `team_mode` and `uefi_device_path`.
DHCPv4/DHCPv6/SLAAC use typed nested views; each contains `json` and Field-valued
properties. For example, `interface.dhcpv4.value()` returns an optional
`DHCPv4Configuration`; inspect `dhcp_enabled` without treating Missing or Null as false.

上述字段可通过原有接口读取路径获取；嵌套配置保留原始 JSON 与 Field 三态。读取
`interface.dhcpv4.value()` 后可查看 `dhcp_enabled`，不要把缺失/null 当成 false。
DNS 数组保留顺序、重复和空数组；不解析 DNS、不验证 IP、不推断 IPv6Enabled 或 TeamMode。
配置读取不会执行 Update。网络地址属于调用方数据，示例只输出存在性和数量。

See [the complete added-field list and differential evidence](gofish/READONLY-02.md).
Missing/null/defaults and null DNS members still differ from GoFish. This is not full
EthernetInterface/address/VLAN/update support; those gaps remain in the item matrix.
详见字段清单与差分证据；缺失/null/默认值及 DNS null 成员仍有差异，地址/VLAN/写入等
能力继续保留在矩阵中，未冒称完整 EthernetInterface 一致。


## PCIe inventory (Unreleased) / PCIe 清单（未发布）

Use `resource.pcie_device()` / `.pcie_function()` for typed device/function metadata.
`client.system_pcie_devices(system)` and `system_pcie_functions(system)` read the system's
explicit top-level arrays. `client.chassis_pcie_devices(chassis)` prefers the collection
then legacy links; `client.pcie_functions(device.resource)` prefers nonempty legacy links
then the collection. `client.pcie_function_device(function.resource)` reads the advertised
parent only. No path is guessed or topology automatically recursed.

设备/功能视图包含选定资产、PCI 标识、总线位置字符串、功能类型/协议、健康和接口代际。
五条入口按显式数组/集合/单链接读取；机箱与设备的来源优先级不同，详见
[PCIe 范围、实测及限制](gofish/READONLY-03.md)。不猜路径、不自动递归，不把 ReadyToRemove
等状态当作操作授权。lane 和 FunctionId 使用既有非负 Int32，默认值与厂商宽松转换差异
汇入[集中决策](gofish/DECISIONS.md)，不宣称完整 PCIe/GoFish 一致。


## Boot and Secure Boot (Unreleased) / 启动配置与安全启动（未发布）

`resource.boot()` returns Field[Boot] for nested ComputerSystem.Boot. BootOrder and
AliasBootOrder retain order/duplicates, and override/next/retry/fault/trusted-module
policy strings remain reported data. `resource.boot_option()`, `.secure_boot()`,
`.secure_boot_database()` and `.signature()` expose selected resource metadata.
`client.boot_options(system)`, `secure_boot(system)`, `secure_boot_databases(secure.resource)`
and `signatures(database.resource)` follow only the advertised links, one bounded call
at a time. SecureBootCurrentBoot and SecureBootEnable are separate current/next values.

五个视图和四条导航沿用 Field 与原始 JSON；当前与下次安全启动状态不合并。BootOrder
不重排 BootOptions 集合，HTTP/UEFI 路径和签名不被执行、下载或验证。只读取当前 Boot，
不自动读取/应用 Settings。不提供启动设置、密钥重置或证书登记。
See [exact fields, limits and differential evidence](gofish/READONLY-04.md) and
[the related upstream issues](gofish/ISSUES.md). Full models and compatibility decisions
remain open; raw annotation retention does not imply a typed ExtendedInfo API.


## Task inventory (Unreleased) / 任务清单（未发布）

Read `client.task_service(client.service_root())`, then `client.tasks(service.resource)`
when the service is present. `resource.task_service()` and `.task()` decode the selected
views. Task.messages contains typed Message values with raw JSON. Call
`client.sub_tasks(task.resource)` or `client.task_created_resources(task.resource)`
explicitly to inspect linked children or already-created resources. The latter returns
Resource because created objects can have different types.

任务服务发现沿 ServiceRoot.Tasks；任务状态、进度和消息分别保留，不从严重程度推导
TaskStatus。子任务不递归，已创建资源不猜类型。数量字段沿用非负 Int32，未做 0–100
schema 范围或交叉字段校验，不轮询 monitor、不回放 Payload、不执行解决步骤。
See [field scope and differential evidence](gofish/READONLY-05.md). Generic per-property
ExtendedInfo and TaskMonitor/control lifecycle remain unimplemented. Message and task
raw data remain caller-owned and may contain private values; the offline example prints
only synthetic presence/counts.


## Certificate inventory (Unreleased) / 证书清单（未发布）

`resource.certificate()` exposes selected metadata and Field[CertificateIdentifier]
issuer/subject values. Discover `client.certificate_service(root)`, then
`certificate_locations(service)` and `certificate_location_certificates(locations)`;
the first two return Resource. `client.certificates(owner)` reads top-level collections,
`boot_certificates(system)` reads only Boot.Certificates, and
`certificate_subjects(certificate.resource)` follows Links.Subjects once.

证书视图保留正文、格式、用途、指纹、身份和有效期字符串；不进行密码学或信任判定。
顶层与 Boot 集合不混用，导航不递归，未引入登记、续期、替换或信任安装。所有字段保留
三态与原始 JSON；详细属性、版本和差分见[证书批次](gofish/READONLY-06.md)。


## Virtual media (Unreleased) / 虚拟介质（未发布）

`resource.virtual_media()` retains selected reported connection/image/media/transfer fields,
Inserted, WriteProtected, VerifyCertificate and Status. `client.virtual_media(owner)` reads
an explicit ComputerSystem or Manager VirtualMedia collection. `client.certificates(media)`
and `virtual_media_client_certificates(media)` read server and client certificate collections
separately. Image is data: the client neither downloads it nor uses its UserName/Password.
VerifyCertificate is the reported service setting, not this client's TLS configuration.

`supports_media_insert` and `supports_media_eject` are derived Bool values: true means the
respective advertised action target is a nonempty string, matching the pinned GoFish decoder.
It does not validate the target, grant permission or guarantee that a call would succeed.
ActionInfo-only objects do not set these flags. No control or ActionInfo convenience API is added.

虚拟介质视图保留连接、映像、介质类型、传输和挂载/写保护/证书校验报告值；系统与管理器
集合显式读取，服务器与客户端证书集合分开。Image、UserName 仅是数据，VerifyCertificate
不改变本客户端 TLS。两个派生 Bool 只说明对应动作 target 非空，不代表权限或可执行性。
不会因动作声明自动请求 ActionInfo、访问映像、挂载或弹出。其余报告属性仍使用三态。
详细范围及差分见[虚拟介质批次](gofish/READONLY-07.md)。


## Action metadata (Unreleased) / 动作元数据（未发布）

`resource.action_info()` reads Parameters with ten selected string/array/bool fields per
parameter. `info.param_values(name, data_type)` returns the first matching parameter's
AllowableValues without merging duplicates, falling back to later entries or applying defaults.
For this lookup only, missing/null names map to empty and missing/null/empty DataType is a
wildcard, matching the pinned GoFish search. The returned AllowableValues retains Field;
no matching parameter raises InvalidResponse. Numeric bounds remain unmodeled raw data.

`client.action_info(owner, "#ComputerSystem.Reset")` reads exactly the named Actions entry's
`@Redfish.ActionInfo` string under existing path/time/byte limits. It never follows `target`
or selects a different action. System/Manager reset and VirtualMedia insert metadata reads
are compared. No EjectMediaActionInfo convenience mapping or defect exception is declared.

ActionInfo 保留十个非数值参数属性与原 JSON；首次匹配查询按名称/类型选定一项，保留该项
AllowableValues 三态，不合并、不回退、不应用默认值。只在查询比较时，缺失/null 名称按空
字符串、缺失/null/空 DataType 按通配处理；未匹配报错。数值上下限仍在原 JSON。
显式动作名注解读取复用既有边界，不读取 target、不替换动作、不调用控制。详情与差异见
[批次 08](gofish/READONLY-08.md)，弹出链接疑点见[参考核验](gofish/ACTION-INFO-ROUTING-01.md)。
