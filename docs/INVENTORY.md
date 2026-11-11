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

Every selected typed property is `Field[T]`:

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
