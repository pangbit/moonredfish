# PCIe inventory reads / PCIe 清单读取

Read-only implementation batch 03 · 2026-11-11 · GoFish v0.27.0 at
`4cc897fb5c172996e8f34a31a5d1012b45a287a7`.
Reference headers: **PCIeDevice.v1_21_0** and **PCIeFunction.v1_7_0**, release 2025.4.

This batch adds typed PCIe devices, functions and interface details, plus five explicit
read entry points. Applications can discover devices from a ComputerSystem or Chassis,
read the device's functions and follow a function's advertised parent device. Traversal
is explicit; reading a ReadyToRemove/Enabled/indicator flag never changes the device.

本批新增 PCIe 设备、功能及接口信息类型化读取，并提供五条显式导航入口。应用可从系统或
机箱发现设备，读取设备功能，再按功能给出的链接读取父设备。不隐式递归扫描拓扑；读取
ReadyToRemove、Enabled 或指示灯状态不会触发控制动作。

## Implemented API / 已实现 API

| Public API | Input and behavior / 输入与行为 |
| --- | --- |
| `Resource::pcie_device()` | Selected asset identifiers, firmware, device type, reported flags, interface details and health / 选定资产标识、固件、设备类型、状态标志、接口信息和健康 |
| `Resource::pcie_function()` | PCI vendor/device/subsystem/revision IDs, class, bus/segment/device/function strings, ARI, function ID, protocol/type, enablement and health / PCI 标识、总线位置字符串、ARI、功能编号、协议类型及健康 |
| `Client::system_pcie_devices(system)` | Top-level ComputerSystem.PCIeDevices **array** / 系统顶层链接数组 |
| `Client::system_pcie_functions(system)` | Top-level ComputerSystem.PCIeFunctions **array** / 系统顶层功能链接数组 |
| `Client::chassis_pcie_devices(chassis)` | PCIeDevices collection first; otherwise legacy Links.PCIeDevices / 优先集合，否则旧 Links 数组 |
| `Client::pcie_functions(device)` | Nonempty legacy Links.PCIeFunctions first; otherwise PCIeFunctions collection / 优先非空旧 Links 数组，否则集合 |
| `Client::pcie_function_device(function)` | Links.PCIeDevice singleton only / 仅沿显式父设备单链接 |

`PCIeDevice` adds 15 selected property mappings, `PCIeFunction` 18, and `PCIeInterface`
four (LanesInUse, MaxLanes, PCIeType, MaxPCIeType). Each view retains Resource/raw JSON;
PCIeInterface retains its original nested JSON. Status is the existing selected Health
view, not a new claim of complete Status coverage. Hexadecimal identifiers and BDF/ARI
strings are preserved; no casing, prefix, numeric interpretation or derived fields are
invented. Enum strings remain open. Field preserves Missing/Null/Value.

三个模型分别增加 15、18、4 个属性映射，保留原始 JSON。Status 沿用既有选定健康视图，
不宣称完整 Status 支持。十六进制标识、总线位置与 ARI 字符串原样保留，不补位、不转换、
不推导其他字段；未知枚举字符串与 Field 三态继续保留。

Lane counts and FunctionId use the existing nonnegative Int32 decoder, including exact
integrality checks and the existing decimal/exponent policy. This **differs** from GoFish;
see the measured cases below. CXL, slots, metrics, assembly/environment links, additional
related resources, all enum constants, update serialization and Update remain open.

lane 数与 FunctionId 沿用非负 Int32 严格解码，包括整数性校验；它与 GoFish 存在已实测
差异。CXL、插槽、指标、装配/环境链接、其余关联资源、完整枚举常量、序列化和 Update
继续保留为未完成，原始 JSON 不冒充这些缺失的类型化能力。

## Traversal contract / 遍历契约

The source priorities above follow the pinned GoFish methods on the measured valid link
forms. Absent/null results still preserve native Field states rather than Go nil/empty
slices. Explicit empty arrays remain Value([]). Malformed advertised paths are validated
before array-member GETs; only root-relative Redfish paths are accepted. Paths are
first-occurrence deduplicated, and each public traversal shares its existing timeout,
byte and member budgets. Collections also retain page/cycle limits. No automatic retry,
external-host traversal, full topology recursion or device write is introduced.

The bounded link-array helper is shared with the existing Storage.Drives reader; its
validation-before-read, typed decode order and budgets are preserved and mock regressions
passed. A sequence of separate public calls has separate budgets, not one implicit
whole-topology transaction. Unselected malformed fields and every mixed link shape are
not exhaustively equivalent to GoFish's eager typed decoding.

已测合法链接形式的优先级与固定 GoFish 方法一致。缺失/null 与 Go nil/空数组的表示差异
保留。链接数组先校验全部目标再 GET，按首次出现去重，并共享每次调用的时限、字节和成员
预算；集合仍有页数与循环限制。公用链接数组读取器也用于既有 Storage.Drives，其验证顺序
和预算回归已通过。多次独立调用各有预算，不构造隐式整图事务；未穷尽所有畸形混合链接。

## Evidence and differences / 证据与差异

```sh
moon run examples/extended --target native
python3 tools/test_pcie.py
python3 tools/test_pcie.py --report /tmp/pcie-evidence.json
```

[Raw report](readonly-03.json) includes explicit inputs, typed outputs/error categories,
fixture/source hashes, item IDs and actual request sequences. Local evidence is macOS
arm64, Go 1.24.0 and MoonBit native 0.10.20+65efd5b93; Linux CI runs the same suite.
The source hashes plus subject_base_commit identify the tested changes; prior batches
remain historical snapshots. Complete projections are asserted; focused cases retain
only their indicated property in the report. Concurrent reference member request order
is recorded; multiplicities and returned source order are asserted without sorting away
result differences.

The 32 cases cover defined data, unknown generations, missing/null, exact lane counts,
vendor coercions, five navigation APIs, pagination, source priority, duplicate links,
prevalidation and member 403 with partial results. Twelve selected observations agree,
two both reject with different error categories, and eighteen expose differences.
All 40 native tests and synthetic mock integration passed locally. **These are bounded
functional observations, not full PCIe equivalence or a completion percentage.**
48 declarations acquire candidate mappings: **311 P / 11,269 U / 0 V**.

32 个场景覆盖有值数据、未知代际、缺失/null、lane 精度、厂商转换、五条导航、分页、来源
优先级、重复、预校验及成员 403/部分结果。12 个选定观测相同，2 个两端拒绝但错误不同，
18 个仍有差异；40 项 native 测试和 mock 通过。候选映射增至 311 P，仍为 11,269 U / 0 V。
这些是具体功能证据，不是 PCIe 全量一致或完成百分比。

| Exact input / 确切输入 | GoFish result / GoFish 表现 | moonredfish result / 当前表现 | Impact / 影响 |
| --- | --- | --- | --- |
| `PCIeInterface.LanesInUse = "8"` | Value 8 | InvalidResponse | Vendor string workaround absent / 不自动转换厂商字符串 |
| `LanesInUse = "not-a-number"` or `true` | Value 0 | InvalidResponse | Invalid value can appear as a valid zero lane count / 无效数据可能变成合法零值 |
| `LanesInUse = 1.5` | Value 1 | InvalidResponse | Fraction silently truncated / 小数被取整 |
| `LanesInUse = 16777217` | Value 16777216 | Value 16777217 | Reference float32 intermediate loses precision / 参考端中间 float32 丢精度 |
| `PCIeInterface = []` | Zero-valued interface | InvalidResponse | Vendor empty-array exception vs object validation / 空数组特例与对象校验不同 |
| `FunctionId = 1.0` | JSON type error | Value 1 | Integer spelling differs / 整数拼写规则不同 |
| System PCIeDevices `[D0,D0]` | Two results, two member GETs | One result, one GET | Duplicates and request counts differ / 重复及请求次数不同 |
| System PCIeDevices `[D0,denied]` (403) | D0 plus CollectionError | HTTP error, no returned array | Partial data requires an explicit result contract / 部分结果须明确契约 |
| System PCIeDevices `[D0,"/outside"]` | Fetches both on synthetic loopback | InvalidPath before either member GET | Link scope and failure timing differ / 路径范围与失败时机不同 |

`D0`, `denied` and `/outside` in the table denote `@odata.id` link objects; the JSON
report contains the complete exact payloads.

Do not silently reproduce the lossy vendor coercions or change existing strict defaults.
The [consolidated decision review](DECISIONS.md) records the options, recommendations
and consequences for the original no-differences goal. These open choices did not block
independent inventory and topology reads. No physical device or publication was used.

不静默复制有损厂商转换或修改严格默认值。合并决策文档列明输入、影响、推荐及对原始
零差异目标的后果；这些待决项未阻塞独立清单与拓扑读取。无实机操作或发布。

Pinned source: [PCIeDevice and interface decoder](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/pciedevice.go),
[PCIeFunction](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/pciefunction.go),
[numeric helpers](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/utils.go).
