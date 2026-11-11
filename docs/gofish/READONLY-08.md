# ActionInfo reads and queries / 动作元数据读取与查询

Read-only batch 08 · 2026-11-11 · GoFish v0.27.0 at
`4cc897fb5c172996e8f34a31a5d1012b45a287a7` · [Raw evidence](readonly-08.json).

This batch exposes reported action parameters and deterministic allowable-value lookup.
It also reads a caller-named action's explicit metadata annotation. Reading an action's
metadata does not execute it or authorize execution. The existing Field, error, path and
TLS contracts remain unchanged. Numeric parameter bounds are retained as raw JSON only;
this batch does not revisit unresolved numeric contracts or rerun the official numeric probes.

本批读取动作参数并提供确定性的允许值查询，也可读取调用方明确选择的动作元数据注解。
读取不等于执行或授权；现有三态、错误、路径、TLS 契约不变。参数数值上下限仍仅保留在
原 JSON 中，不裁决数值契约，也不重复运行已有官方数值探针。

## Public API / 公开 API

| API | Behavior / 行为 |
| --- | --- |
| `Resource::action_info()` | Parameters as Field[Array[ActionInfoParameter]], original Resource retained / 参数数组及完整原资源 |
| `ActionInfoParameter` | 10 selected string/array/bool properties, nested raw JSON / 10 个字符串、数组、布尔属性与嵌套原 JSON |
| `ActionInfo::param_values(name, data_type)` | First matching parameter's AllowableValues; no merge, interpolation or fallback / 首次匹配项的允许值，不合并或插值，不回退 |
| `Client::action_info(owner, action)` | GET of exactly Actions[action].@Redfish.ActionInfo, within existing budgets / 按明确动作名读取注解 URI，沿用预算 |

Selected parameter properties: Name, DataType, DefaultValue, ObjectDataType, AllowablePattern,
AllowableNumbers, AllowableValueDescriptions, AllowableValues, NoDefaultValue and Required.
All use Field. Unknown strings, array order, duplicates and contradictory reported metadata
are retained. DefaultValue is a string, not parsed JSON; AllowablePattern is not compiled;
AllowableNumbers ranges/durations are not interpreted. Descriptions are not zipped to values
or padded when lengths differ. Required/NoDefaultValue do not synthesize or remove a default.

10 个属性保留三态；未知值、数组顺序、重复、相互矛盾的报告不自动修正。DefaultValue
不解析为 JSON，AllowablePattern 不编译，AllowableNumbers 不解释范围/步长/时长；描述
数组不与值强行配对或补齐，Required/NoDefaultValue 不触发默认值处理。

Lookup follows the pinned GoFish algorithm: names compare case-sensitively; a reported
nonempty DataType must equal the requested type. Missing/null/empty reported DataType is
a wildcard. For lookup comparison only, missing/null names compare as an empty string.
The first matching entry wins even when its AllowableValues is missing, null or empty;
there is no search for a later nonempty list. The returned Field retains those states.
If Parameters is missing/null/empty or no entry matches, native raises InvalidResponse;
GoFish returns its ordinary not-found error. This selected helper behavior is not approval
of a global scalar-default mapping or compatibility mode.

查询名称区分大小写；非空 DataType 须与请求类型相等，缺失/null/空类型为通配。仅查询
比较时缺失/null 名称视为空。首次匹配即返回，允许值缺失/null/空数组均不继续寻找后项，
返回值保留三态；无参数或无匹配时报错。该明确算法不等于批准全局默认值映射或兼容模式。

Annotation reads are compared with ComputerSystem.ResetActionInfo, Manager.ResetActionInfo
and VirtualMedia.InsertMediaActionInfo. They do not need an action target or infer a path
from one. Missing/null annotations return Missing/Null without a metadata GET; a malformed
selected annotation fails; empty/unsafe paths fail validation; advertised HTTP errors surface.
Each call shares a total-byte and operation-time budget; normal per-request limits apply.
No fallback chooses another action or an inline allowable-values property.

注解读取已对照系统/管理器 Reset 和虚拟介质 Insert 的元数据方法，不要求或读取 target，
不猜路径、不切换动作、不回退到内嵌允许值。缺失/null 不发 GET；畸形、空或危险路径及
HTTP 错误按现契约处理。每次调用有总字节/操作时间预算，并沿用请求级边界。

The generic API is an explicitly named annotation reader, not a compatible implementation
of VirtualMedia.EjectMediaActionInfo. That GoFish method remains an unmapped gap pending
its [two-reference review](ACTION-INFO-ROUTING-01.md). No control or defect exception was added.

通用 API 按调用方给出的名称读取，不冒充 EjectMediaActionInfo 兼容实现。后者仍未映射，
参见双参考核验；未新增控制功能或缺陷例外。

## Verification / 验证

```sh
moon run examples/extended --target native
python3 tools/test_action_info.py
python3 tools/test_action_info.py --report /tmp/action-info-evidence.json
```

32 synthetic loopback cases assert independent expected projections, query results, errors
and exact GET traces through both clients. **13 selected observations agree** (including a
common HTTP error), **7 both reject with different categories**, and **12 differ**. Cases
cover full/missing/null/empty metadata, unknown types, selected and unselected malformed
fields, null array entries, first-match ordering, type filtering/wildcards, case sensitivity,
three real GoFish metadata getters, absent/null/empty annotations, denied and unsafe paths.
No control request, target traversal, login or real endpoint is used. Source/fixture hashes
and the subject base commit identify the tested code. All **55 native tests**, check, release
build and the offline example passed locally on macOS arm64. Linux CI runs this differential
suite alongside existing comparisons; both-platform CI retains the mock integration suite.

32 个实际场景检查值、错误和请求轨迹；13 个选定观测相同（含一个相同 HTTP 错误）、
7 个双方拒绝但分类不同、12 个有差异。55 项 native、检查、release 与离线示例本地通过；
Linux CI 纳入对照。未请求控制 target、登录或实机；原始报告提供输入与源码哈希。

| Concrete input / 确切输入 | GoFish | moonredfish | Existing decision |
| --- | --- | --- | --- |
| Parameters missing / null | nil slice | Missing / Null | D-PRESENCE |
| Parameters `[null]` | Zero parameter | InvalidResponse | D-JSON |
| AllowableValues `[null]` | `[""]` | InvalidResponse | D-JSON |
| Unselected MaximumValue `"wrong-type"` | Whole typed GET fails | Selected nonnumeric metadata readable | D-JSON / eager versus selected decoding |
| First matching parameter lacks AllowableValues | nil; no later fallback | Missing; no later fallback | D-PRESENCE; matching order agrees |
| No matching name/type | ordinary not-found error | InvalidResponse | D-API / error representation |
| Missing or null ActionInfo annotation | unsupported error | Missing or Null | D-PRESENCE / D-API |
| Empty annotation | unsupported error | InvalidPath | D-SAFE / error representation |
| Same-host `/outside` annotation | GETs metadata | Rejects before metadata GET | D-SAFE |

**17 new candidates; 462 P / 11,118 U / 0 V.** Numeric bounds, complete enums/OEM/serialization,
other resource-specific getters and all action construction/execution remain gaps. The
[three review topics](DECISIONS.md) are unchanged, and official numeric differences remain
unresolved. The two additional GoFish routing probes are separate from these 32 comparisons
and do not count as native equivalence or official runtime verification.

新增 17 个候选，总计 **462 P / 11,118 U / 0 V**。数值上下限、完整枚举/OEM/序列化、
其他专用 getter 和动作构造/执行仍有缺口。三个待审主题及数值未决结论不变；另外两个
GoFish 路由复现不计入本批 32 对照，不当作 native 一致或官方运行证据。

Reference header: [ActionInfo.v1_5_0 / 2025.3](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/actioninfo.go).
No real-device operation or Mooncakes publication occurred.
