# Consolidated compatibility decisions / 合并兼容性决策

**Open for one combined review. No exception or migration is approved by this document.**
**集中审阅，全部待决；文档本身不批准例外、契约迁移、控制或实机操作。**

Target: every public capability of GoFish v0.27.0 at
`4cc897fb5c172996e8f34a31a5d1012b45a287a7`. Current API is a native MoonBit read-only subset.
Literal Go source/ABI identity is impossible for that API. The proposed target is explicit
one-to-one translation of observable behavior. Retained exceptions leave the original
no-differences target unmet; passing selected examples does not close whole API rows.

目标为固定 GoFish 版本全部公开能力。建议确认跨语言一对一可观察语义映射；字面 Go 源码/
ABI 兼容需要另一种架构。任何保留的例外都意味着原零差异目标未完成，不能改写验收口径。

Evidence: [batch 01](READONLY-01.md), [batch 02](READONLY-02.md), [batch 03](READONLY-03.md).
Each JSON report has exact inputs, observed states, source hashes and environment. Cases
below are measurements unless marked **source only**. No authentication downgrade or
control operation is implied by a fixture or recommendation.

| Decision | Concrete input and both behaviors / 输入及两方表现 | Caller impact / 影响 | Recommendation for review / 推荐决策 |
| --- | --- | --- | --- |
| D-API / D-PRESENCE | `DHCPv4:null`: Go zero struct (false/empty); MoonBit Null. `DHCPv6:{}`: Go zero members; MoonBit nested Missing. Omitted scalar bool/string similarly differ / null、空对象、标量缺失均有默认值差异 | Missing configuration may look disabled; native return types change / 缺失可能看似禁用，返回类型迁移影响调用方 | Approve explicit native pointer/nil/scalar-default mapping and a migration plan; retain raw JSON for presence inspection. Until approved keep the existing Field API / 明确默认值映射与迁移，原始 JSON 保留存在性，批准前沿用 Field |
| D-NUM | `CapacityBytes:9223372036854775807`: 64-bit Go accepts exactly; MoonBit rejects above 2^53−1. `FunctionId:1.0`: Go rejects, MoonBit accepts integral spelling / 范围与拼写不同 | Narrowed range and changed accepted inputs / 表达范围及合法输入不同 | For full parity choose property-specific exact numeric types, fixed architecture semantics and Go-compatible lexical rules; do not silently round/clamp / 完整对齐须逐字段精确类型、架构边界与拼写规则，不舍入截断 |
| D-VENDOR-NUM (extends D-NUM/D-JSON) | PCIe `LanesInUse:16777217`: Go 16777216, MoonBit 16777217. `"not-a-number"` or true: Go 0, MoonBit error. `1.5`: Go 1, MoonBit error. `PCIeInterface:[]`: Go zero struct, MoonBit error / 有损转换与空数组特例 | Invalid data can appear valid; copying behavior introduces precision loss / 无效数据伪装零值，复制行为会丢精度 | Recommend retaining strict/exact decoding pending an explicit choice. Either approve exact reference quirks in a defined compatibility contract, or approve a documented exception that keeps full parity open. An upstream/reference change needs a separate baseline decision / 建议先保留严格精确解码；逐项决定复刻缺陷或接受明确例外，不能声称二者同时零差异 |
| D-JSON | Duplicate CapacityBytes 1 then 2: Go 2, MoonBit error. `NameServers:[null]`: Go [""]，MoonBit error. Invalid UTF-8: Go replacement string, MoonBit error. Typed GET trailing JSON: Go consumes first object, MoonBit rejects / 宽松输入处理不同 | Ambiguous data, unusable DNS entries, changed validation / 数据歧义、无效 DNS、校验变化 | Keep strict defaults until the compatibility/default choice is explicit; define each coercion separately, not a blanket permissive decoder / 不整体放宽，逐项确定转换规则 |
| D-DEFAULT-INTENT | Gateway present, IPv6Enabled omitted: Go false, MoonBit Missing, pinned source comment describes true. TeamMode omitted: Go empty, MoonBit Missing, comment describes None / 注释默认值与实际解码不同 | Inferring comments changes the reference behavior / 按注释推断会偏离实际参考 | For compatibility use measured Go behavior after default mapping approval; never synthesize true/None merely from comments / 兼容参照以实际行为为准，批准前不凭注释补值 |
| D-COLLECTION | `[D0,D0]`: Go two results/GETs, MoonBit deduplicates. `[D0,403]`: Go D0+CollectionError, MoonBit error without array. Embedded member names can differ from fetched resource / 重复、部分结果、内嵌不同 | Return shape, topology observations and request count change / 返回形态、拓扑观测及请求数量变化 | Approve a result carrying both items and error, preserving source order/duplicates and reference inline selection. Existing throw-only behavior cannot be called equivalent / 明确结果加错误的返回形态，保留参考顺序、重复与内嵌选择 |
| D-SAFE / D-AUTH | Synthetic `[D0,"/outside"]`: Go fetches both on same loopback host, MoonBit rejects before member GET. **Source only:** Go exposes HTTP/Insecure, explicit BasicAuth/imported Session; session failure returns error, not automatic Basic fallback / 路径范围差异已测；认证选项仅源码审阅 | Broader link/transport/auth behavior can change credential handling / 扩大路径、传输和认证行为可能改变凭据处理 | Keep current safe defaults; separately approve explicit auth/transport/link options if required. Never add implicit downgrade. Retained differences remain open / 安全默认值保留；选项逐项决定，禁止凭空增加隐式降级 |

D-PLATFORM, D-HARDWARE and D-CONTROL from the [full plan](../GOFISH_PARITY.md) remain open.
Current evidence is native Linux x86_64 CI and macOS arm64 local/CI; it does not establish
all Go platforms or any physical hardware/firmware/role profile. Nothing here authorizes
real devices or publication. Control development remains outside these read-only batches.

平台、硬件和控制门槛继续有效。现有证据不覆盖所有 Go 平台或实机型号/固件/权限组合；
本次合并审阅不授权实机、发布或控制开发。

Independent work continues under the existing contract: read models, explicit links,
non-coercive fields, bounded traversal and targeted differential evidence. These decisions
block only affected API/default/security migrations; they do not block unrelated reads.

独立工作继续推进：读取模型、显式链接、不需要转换的字段、有界遍历及针对性差分。待决项
只阻塞相关契约/默认值/安全迁移，不阻塞其他读取功能。所有条目维持未完成或候选状态，
只有完成获批契约和相关环境验收才能转为 V。
