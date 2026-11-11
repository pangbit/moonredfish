# Consolidated compatibility decisions / 合并兼容性决策

**Case decisions remain open. The user-approved defect gate is below; no verified exception or API migration yet.**
**具体差异仍待审阅；用户已确认的缺陷门槛见下文，目前尚无已核实例外或 API 迁移。**

The user has approved the conditional [two-DMTF confirmed-defect rule](EXCEPTIONS.md).
That rule permits a public exception only after a GoFish error and both official reference
behaviors are verified. No case has met that gate yet; unsupported/disagreeing evidence
remains unresolved. Normal functional alignment remains the goal.
用户已确认双 DMTF 核实后的缺陷例外原则；目前无已核实案例，不将未覆盖或冲突证据当作批准。

The user is reviewing the proposed accurate/error-reporting default plus optional GoFish
compatibility mode. That is a recommendation, **not an approved decision**; no mode is
implemented. Read-only work continues with the existing Field and strict-decoding contract.
用户正在审阅默认准确且明确报错、另提供兼容模式的建议；尚未批准，也未实现模式。

## Three review topics / 三个合并审阅主题

These are proposals, not decisions or prerequisites for unrelated read work. The first two
matter before changing existing public contracts; the third matters before adding broader
transport/auth options. Numeric candidates with missing comparable official field contracts
remain unresolved under the already-approved defect gate; no new blanket exception is requested.

以下仅是建议，不是已批准决定，也不阻塞独立读取。前两项用于公共契约迁移前，第三项用于
扩大传输/认证选项前；官方字段契约未覆盖的数值差异继续未决，不请求笼统例外。

| Topic / 主题 | Concrete impact / 具体影响 | Proposed choice for review / 待审建议 |
| --- | --- | --- |
| 1. API, presence and decoding / API、存在性与解码 | VirtualMedia `{}` yields Go Inserted=nil and VerifyCertificate=false; native both Missing. `MediaTypes:[null]` becomes Go `[""]`, native error. A single implicit mapping loses distinctions / 隐式映射会丢失三态或改变合法输入 | Retain the current explicit Field/error default and, if approved, define a separate GoFish-compatible interface with per-property mappings and exact numeric representation. Confirm this dual-contract direction before implementation; it cannot be called literal zero-difference native behavior / 建议保留现默认，批准后逐字段定义独立兼容接口及精确数值表示；双契约方向须明确，不能称 native 字面零差异 |
| 2. Collection result contract / 集合结果契约 | `[M0,403]` yields Go M0+CollectionError, native throws without items; duplicates and inline selection also differ / 部分可用数据、数量与来源不同 | Use an explicit items-plus-error result in the compatible interface, preserve reference order/duplicates/inline choice, and keep any migration of existing methods separate / 兼容接口建议显式 items+error，保留顺序、重复和内嵌选择；既有方法迁移另行确定 |
| 3. Link, authentication and diagnostics options / 链接、认证与诊断 | Go fetches a same-host `/outside` link that native rejects; HTTP/Insecure/Basic/imported-session options and credential-bearing dumps need distinct contracts / 可访问路径及凭据处理范围改变 | Keep current verified HTTPS/path/default behavior; review explicit options individually when needed, with no implicit downgrade and no credential/body dumping. Any remaining difference must be visible / 建议保留当前默认，新增选项逐项决定，不隐式降级或输出凭据正文；差异公开 |

No choice here authorizes real hardware, controls, publication, or a reference-version upgrade.
这些主题不授权实机、控制、发布或升级参照版本。

Target: every public capability of GoFish v0.27.0 at
`4cc897fb5c172996e8f34a31a5d1012b45a287a7`. Current API is a native MoonBit read-only subset.
Literal Go source/ABI identity is impossible for that API. The proposed target is explicit
one-to-one translation of observable behavior. Retained exceptions leave the original
no-differences target unmet; passing selected examples does not close whole API rows.

目标为固定 GoFish 版本全部公开能力。建议确认跨语言一对一可观察语义映射；字面 Go 源码/
ABI 兼容需要另一种架构。任何保留的例外都意味着原零差异目标未完成，不能改写验收口径。

Evidence: [batch 01](READONLY-01.md), [batch 02](READONLY-02.md), [batch 03](READONLY-03.md), [batch 04](READONLY-04.md), [batch 05](READONLY-05.md), [batch 06](READONLY-06.md), [batch 07](READONLY-07.md), [batch 08](READONLY-08.md).
[Upstream issue review](ISSUES.md) separates open reports from pinned behavior and later fixes.
Each JSON report has exact inputs, observed states, source hashes and environment. Cases
below are measurements unless marked **source only**. No authentication downgrade or
control operation is implied by a fixture or recommendation.

| Decision | Concrete input and both behaviors / 输入及两方表现 | Caller impact / 影响 | Recommendation for review / 推荐决策 |
| --- | --- | --- | --- |
| D-API / D-PRESENCE | `DHCPv4:null`: Go zero struct (false/empty); MoonBit Null. `DHCPv6:{}`: Go zero members; MoonBit nested Missing. Omitted scalar bool/string similarly differ / null、空对象、标量缺失均有默认值差异 | Missing configuration may look disabled; native return types change / 缺失可能看似禁用，返回类型迁移影响调用方 | Approve explicit native pointer/nil/scalar-default mapping and a migration plan; retain raw JSON for presence inspection. Until approved keep the existing Field API / 明确默认值映射与迁移，原始 JSON 保留存在性，批准前沿用 Field |
| D-NUM | `CapacityBytes:9223372036854775807`: 64-bit Go accepts exactly; MoonBit rejects above 2^53−1. `FunctionId:1.0`: Go rejects, MoonBit accepts integral spelling / 范围与拼写不同 | Narrowed range and changed accepted inputs / 表达范围及合法输入不同 | For full parity choose property-specific exact numeric types, fixed architecture semantics and Go-compatible lexical rules; do not silently round/clamp / 完整对齐须逐字段精确类型、架构边界与拼写规则，不舍入截断 |
| D-VENDOR-NUM (extends D-NUM/D-JSON) | PCIe `LanesInUse:16777217`: Go 16777216, MoonBit 16777217. `"not-a-number"` or true: Go 0, MoonBit error. `1.5`: Go 1, MoonBit error. `PCIeInterface:[]`: Go zero struct, MoonBit error / 有损转换与空数组特例 | Invalid data can appear valid; copying behavior introduces precision loss / 无效数据伪装零值，复制行为会丢精度 | Recommend retaining strict/exact decoding pending an explicit choice. Apply the user-approved two-DMTF gate to suspected defects and publicly document verified exceptions; otherwise keep the exact compatibility choice unresolved. A baseline change needs a separate decision / 疑似缺陷按已确认双 DMTF 门槛核实并公开例外，其余兼容选择未决，不同时声称例外与字面零差异 |
| D-JSON | Duplicate CapacityBytes 1 then 2: Go 2, MoonBit error. `NameServers:[null]`: Go [""]，MoonBit error. Invalid UTF-8: Go replacement string, MoonBit error. Typed GET trailing JSON: Go consumes first object, MoonBit rejects / 宽松输入处理不同 | Ambiguous data, unusable DNS entries, changed validation / 数据歧义、无效 DNS、校验变化 | Keep strict defaults until the compatibility/default choice is explicit; define each coercion separately, not a blanket permissive decoder / 不整体放宽，逐项确定转换规则 |
| D-DEFAULT-INTENT | Gateway present, IPv6Enabled omitted: Go false, MoonBit Missing, pinned source comment describes true. TeamMode omitted: Go empty, MoonBit Missing, comment describes None / 注释默认值与实际解码不同 | Inferring comments changes the reference behavior / 按注释推断会偏离实际参考 | For compatibility use measured Go behavior after default mapping approval; never synthesize true/None merely from comments / 兼容参照以实际行为为准，批准前不凭注释补值 |
| D-COLLECTION | `[D0,D0]`: Go two results/GETs, MoonBit deduplicates. `[D0,403]`: Go D0+CollectionError, MoonBit error without array. Embedded member names can differ from fetched resource / 重复、部分结果、内嵌不同 | Return shape, topology observations and request count change / 返回形态、拓扑观测及请求数量变化 | Approve a result carrying both items and error, preserving source order/duplicates and reference inline selection. Existing throw-only behavior cannot be called equivalent / 明确结果加错误的返回形态，保留参考顺序、重复与内嵌选择 |
| D-SAFE / D-AUTH | Synthetic `[D0,"/outside"]`: Go fetches both on same loopback host, MoonBit rejects before member GET. **Source only:** Go exposes HTTP/Insecure, explicit BasicAuth/imported Session; session failure returns error, not automatic Basic fallback / 路径范围差异已测；认证选项仅源码审阅 | Broader link/transport/auth behavior can change credential handling / 扩大路径、传输和认证行为可能改变凭据处理 | Keep current safe defaults; separately approve explicit auth/transport/link options if required. Never add implicit downgrade. Retained differences remain open / 安全默认值保留；选项逐项决定，禁止凭空增加隐式降级 |

Batch 04 additionally measures `BootOrder:[null]` (Go `[""]`, native error), absent/null
Boot (Go zero struct, native Field), and conflicting inline/linked SecureBoot data (Go
uses inline; native GETs the link). These extend D-JSON, D-PRESENCE and D-COLLECTION/B06;
they do not imply new decisions. Both Go BootOptions getters avoid member GETs on an
absent link; their nil result still differs from native Missing. Current Boot and Settings
remain distinct reads; no SetBoot/ETag control behavior was exercised.

batch 04 将启动列表 null 成员、缺失 Boot 及内嵌/链接 SecureBoot 的不同观测并入既有待决项。
两条 Go BootOptions 入口在链接缺失时均不请求成员，但 nil 与 Missing 仍不同；未执行启动
设置或 ETag 控制。上游 #516 在固定版本中已有 Settings 回退，详见 issue 审阅，不能照抄
其描述为当前实现事实。

Batch 05 adds exact Task cases: PercentComplete 1.0 (Go error, native 1), 2147483648
(Go uint value, native range error), Messages [null] (Go zero Message, native error), and
Payload "not-an-object" (Go eager typed GET error, native selected fields readable).
These extend D-NUM/D-JSON; neither a schema default nor a confirmed GoFish defect is
inferred. Both clients accept PercentComplete 101 and preserve contradictory state/status/
message values. Task messages do not authorize registry lookups, actions or payload replay.

batch 05 的整数拼写/范围、null 消息与未选定 Payload 类型错误，进入既有待决项；不由
这些差异判定 GoFish 错误。两端均接受 101 并保留矛盾报告值，不推导状态或执行解决步骤。

Batch 06 extends the same presence, null-element, inline and partial-result decisions to
certificate reads. Separate [official numeric execution](OFFICIAL-NUMBERS-01.md) now
shows both generic DMTF paths retaining 16777217, original strings/bools/reals and 64-bit
integer values. libredfish's int getter wraps 2147483648 on this build while its long-long
getter preserves it; wrong primitive types can produce zero. These are actual observations,
not an approved replacement typed-field contract or verified exception. Payload/default
and other uncovered cases remain unresolved; do not choose a getter to manufacture agreement.

证书批次沿用既有待决项。八个官方数值实测已完成，但通用 JSON 保留与不同 getter 的
结果不能代替字段校验契约，也不构成已核实例外；未覆盖部分仍未决，不挑选 getter 拼出一致。

Batch 07 adds pointer-versus-scalar boolean evidence without changing the above topics:
Inserted/WriteProtected missing or null become Go nil; VerifyCertificate becomes Go false;
native retains the separate states. MediaTypes null elements and malformed unselected
Password/ActionInfo metadata extend D-JSON. Derived nonempty-target support flags agree on
the measured cases and never imply authorization or action execution. Server/client
certificate sources remain distinct. The source-only EjectMediaActionInfo candidate stays
outside implementation and does not add a fourth immediate user decision.

虚拟介质批次将指针/标量布尔值、null 列表和未选定字段类型差异并入前三主题；派生标志
只表示动作声明。两类证书不混用；ActionInfo 源码候选保留缺口，不追加即时用户决策。

Batch 08 retains the same three review topics. The first-match ActionInfo lookup is explicit:
missing/null reported names compare as empty, missing/null/empty types match any requested
type, and the first selected AllowableValues retains Field. No value merge or default is
invented. Missing annotation versus Go unsupported error, strict null elements and whole-model
numeric-field errors remain differences. [Two actual GoFish routing cases and official source
coverage](ACTION-INFO-ROUTING-01.md) leave EjectMediaActionInfo unresolved: neither reference
establishes a comparable selector contract. No new user decision or exception is inferred.

动作元数据批次继续沿用三个审阅主题；明确查询匹配算法，保留三态和错误差异，不推导默认值。
两个实际 GoFish 路由场景与官方源码审阅仍未满足双参考例外门槛，不追加裁决或预设修复。

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
