# Read-only evidence batch 01 / 只读差分证据 01

2026-11-11 · GoFish v0.27.0 · macOS arm64 · Go 1.24.0 · MoonBit native.
[Machine-readable observations / 原始结果](readonly-01.json) record compiler versions,
source and fixture hashes, exact item IDs, selected values, error categories and actual
request sequences. The containing Git commit identifies this batch; `subject_base_commit`
is its parent checkout, and source hashes identify the tested uncommitted changes.

**39 cases: 7 same selected observations, 10 both reject, 22 known differences.**
At this batch's commit no item was promoted to `V`. The 10 rejection cases have different error types; they are
not evidence of error equivalence. The 7 matching projections cover only the specified
values, not every property, API, wire byte, request schedule or environment.

**39 个场景：7 个选定观测相同、10 个两端拒绝、22 个已知差异。** 本批提交时的矩阵为
234 P / 11,346 U / 0 V（后续映射进展见新批次）。“两端拒绝”不表示错误类型相同；相同投影不关闭整个字段或 API。
证据包含原始结果与请求顺序；Git 所在提交及测试源码哈希定位被测改动。

## Reproduce / 复现

```sh
python3 tools/test_parity.py
# Optional evidence output, after all explicit expectations pass:
python3 tools/test_parity.py --report /tmp/moonredfish-parity.json
```

The runner uses the real typed GoFish `GetDrive` / `GetCollectionObjects[ComputerSystem]`
and moonredfish `get().drive()` / `members()` followed by `get()`. Each client receives
identical synthetic bytes on a fresh numeric-loopback server. No session or device
mutation is used. Expectations are explicit in Python; the runner does not bless the
current outputs as parity. Result arrays are not sorted or deduplicated by the adapters.
GoFish's member-fetch goroutine order is nondeterministic: actual request sequences are
retained and request multiplicities are asserted. Concurrency timing and exact header
semantics remain unverified. Both adapters use the existing test transport settings;
this is not evidence that production defaults match.

使用真实类型化客户端方法，独立回环服务提供同字节输入，不执行会话或设备写入。
断言预期在测试中明确给出，不把实际输出自动当作正确值。保留数组顺序、重复项、部分结果
及错误类别；GoFish 成员并发请求顺序不固定，记录原始顺序并检查每条路径的请求次数。
并发时序、完整错误对象、请求头与默认传输配置仍未验证。

## Fixed defect / 已修复缺陷

Wire numeric text was discarded before integer validation. `1.0000000000000001`,
`9007199254740991.1` and `1e-9999` could round to integral Doubles and pass the existing
nonnegative-integer check. The HTTP JSON decoder now preserves numeric spelling, and
count/capacity helpers check exact decimal integrality before applying existing finite,
nonnegative and Int32 / 2^53−1 bounds. Decimal/exponent spellings that are mathematically
integral remain accepted by today's contract; changing that is D-NUM below.

Both focused regressions failed before the fix. Three regression tests now cover rounded
fractions, underflow, count fields and accepted integral spellings. All 34 native tests
and the synthetic integration suite passed locally. This is a correction of the existing
integer contract, not implementation of GoFish's entire numeric model.

此前数字原文在整数校验前丢失，小数可能先舍入为整数。现保留 HTTP JSON 数字原文并先做
十进制整数性检查，再应用既有有限值、非负和范围限制。复现用的两个回归原先失败，修复后
三个相关测试及全部 34 个 native 测试通过。数学上为整数的 `1.0`/`1e3` 继续接受，未擅改
公开契约。调用者传入的 `Json` 若已丢失原文，无法恢复精度；自行解析应使用
`preserve_number_repr=true`。保留原文也会影响 raw JSON 再序列化的数字拼写。

## Decisions / 需要明确的取舍

| ID | Concrete difference / 具体差异 | Recommendation / 建议 | Gate / 门槛 |
| --- | --- | --- | --- |
| D-PRESENCE (B07, D-API) | Go pointer nil collapses absent/null; scalar bool/string defaults become false/empty. MoonBit exposes Missing/Null/Value / Go 指针合并缺失和 null，标量取零值；MoonBit 保留三态 | Approve explicit one-to-one typed translation: optional pointer and scalar defaults, with raw JSON retained for presence inspection / 明确批准指针可选值与标量默认值映射，原始 JSON 保留存在性信息 | Breaking public return types require approval; current Field contract stays / 返回类型变化须确认 |
| D-NUM (B08, D-API) | 64-bit Go `*int` accepts negative values and up to 2^63−1, rejects `1.0`/`1e3`; current MoonBit allows integral decimal/exponents but caps at 2^53−1 and rejects negatives / 范围、符号与合法数字拼写均不同 | For full parity, migrate each property to an exact type and decoder matching the fixed reference architecture; do not globally round, clamp or substitute strings / 完整对齐应逐字段迁移精确类型和解码规则，拒绝舍入、截断或冒充字符串 | Approve type/validation migration and 32-bit scope first / 先定类型迁移及 32 位边界 |
| D-COLLECTION (B05/B06, D-API) | Duplicate members, inline objects, missing/null Members, member errors and cycles differ; Go can return successful data with error / 重复、内嵌、缺失及失败时部分结果不同 | Preserve source order, duplicates and inline identity; design a result carrying both items and error / 保留顺序、重复与内嵌身份，显式返回结果和错误 | Existing throw-only/incomplete-inventory behavior changes; approve result shape / 须批准结果形态及兼容变化 |
| D-JSON (B09, D-SAFE) | Go last duplicate wins, folds key case, replaces malformed UTF-8, and this GET decoder accepts trailing JSON; MoonBit rejects or treats case variants as missing / 重复键、大小写、坏 UTF-8 与尾随内容行为不同 | Keep the present strict defaults until an explicit compatibility API/default decision; any retained exception keeps the full-parity target open / 先保留严格默认值，兼容入口或默认值变更须明确决定；保留差异就不能宣称完全一致 | Do not silently relax parsing / 不自动放宽 |
| D-AUTH (D-SAFE; source-only) | GoFish has explicit BasicAuth and imported Session, HTTP/Insecure options; current API lacks these. Source shows session-login failure returns an error, **not automatic Basic fallback** / GoFish 有显式 Basic、外部 Session、HTTP 与 Insecure；登录失败并不自动降级 Basic | Add no silent auth fallback. Decide explicit auth/config API separately, preserve credential-safe defaults pending review / 不增加隐式认证降级，显式认证及配置 API 单独决策 | No auth downgrade or insecure transport enabled; this batch has no auth differential evidence / 本批未验证认证差分，也未启用降级 |

Pending platform/hardware/control gates from the [full plan](../GOFISH_PARITY.md) remain.
Approval of one decision does not approve another or authorize a physical action.
平台、硬件和控制门槛继续有效；某项兼容决策不授权其他行为或实机操作。

## Per-case evidence / 逐项证据

`same` means selected observation only; `reject` means both reject with their own errors;
`diff` is an unresolved observed difference. Full values, error categories, item IDs and
request traces are in the JSON report. All cases remain open for whole-item acceptance.

| Case | Behavior | Result |
| --- | --- | --- |
| `capacity_missing` | B07 | diff / 已知差异 |
| `capacity_null` | B07 | diff / 已知差异 |
| `capacity_zero` | B08 | same / 选定相同 |
| `capacity_safe_max` | B08 | same / 选定相同 |
| `capacity_above_safe` | B08 | diff / 已知差异 |
| `capacity_int64_max` | B08 | diff / 已知差异 |
| `capacity_int64_overflow` | B08 | reject / 两端拒绝 |
| `capacity_negative` | B08 | diff / 已知差异 |
| `capacity_fraction` | B08 | reject / 两端拒绝 |
| `capacity_rounded_fraction` | B08 | reject / 两端拒绝 |
| `capacity_large_fraction` | B08 | reject / 两端拒绝 |
| `capacity_underflow` | B08 | reject / 两端拒绝 |
| `capacity_decimal_integer` | B08 | diff / 已知差异 |
| `capacity_exponent_integer` | B08 | diff / 已知差异 |
| `capacity_string` | B08 | reject / 两端拒绝 |
| `boolean_false` | B07 | same / 选定相同 |
| `boolean_missing` | B07 | diff / 已知差异 |
| `boolean_null` | B07 | diff / 已知差异 |
| `boolean_wrong_type` | B09 | reject / 两端拒绝 |
| `enum_unknown` | B07 | same / 选定相同 |
| `enum_missing` | B07 | diff / 已知差异 |
| `enum_null` | B07 | diff / 已知差异 |
| `enum_wrong_type` | B09 | reject / 两端拒绝 |
| `duplicate_key` | B09 | diff / 已知差异 |
| `case_folded_key` | B09 | diff / 已知差异 |
| `invalid_utf8` | B09 | diff / 已知差异 |
| `trailing_json` | B09 | diff / 已知差异 |
| `truncated_json` | B09 | reject / 两端拒绝 |
| `malformed_json` | B09 | reject / 两端拒绝 |
| `collection_order` | B05 | same / 选定相同 |
| `collection_duplicate` | B05 | diff / 已知差异 |
| `collection_embedded` | B06 | diff / 已知差异 |
| `collection_missing_members` | B05 | diff / 已知差异 |
| `collection_null_members` | B05 | diff / 已知差异 |
| `collection_empty` | B05 | same / 选定相同 |
| `collection_unlinked_member` | B05 | diff / 已知差异 |
| `collection_member_failure` | B05 | diff / 已知差异 |
| `collection_paged` | B05 | same / 选定相同 |
| `collection_cycle` | B05 | diff / 已知差异 |

Pinned source evidence: [Drive declarations/unmarshaller][drive],
[collection traversal/partial results][collections], [GET decoder][entity],
[explicit authentication selection][auth]. HTTP typed GET uses one `json.Decoder.Decode`
in `DecodeGenericEntity`; accepting trailing JSON here does not imply direct
`json.Unmarshal` or every GoFish entry point accepts it.

固定源码说明：HTTP 类型化 GET 在 `DecodeGenericEntity` 中只调用一次 Decode；此路径接受
尾随 JSON 不代表 `json.Unmarshal` 或 GoFish 所有入口都如此。

[drive]: https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/drive.go
[collections]: https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/collection.go
[entity]: https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/entity.go
[auth]: https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/client.go
