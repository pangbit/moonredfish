# Confirmed-defect exception gate / 已确认缺陷的例外门槛

User-approved principle, received 2026-11-11:

> 如果确定是GoFish的错误，且与官方的[redfishtool](https://github.com/dmtf/redfishtool)和[libredfish](https://github.com/DMTF/libredfish)对照核实后，可以按照官方实现对齐，并且需要公开记录这些例外。

Normal functionality still targets complete GoFish behavior. A confirmed GoFish error may
instead follow the two named DMTF references once the same relevant behavior is verified
and the exception is public. If either reference does not cover it, results disagree, or
evidence is insufficient, leave it unresolved and offer a concrete recommendation.
A difference, issue report, source comment or generic JSON round trip alone does not
establish a defect in the corresponding typed API or authorize an unrelated migration.

正常功能仍以 GoFish 完整对齐为目标。例外要求确认错误，并核实两个指定参照的相关行为；
未覆盖、不一致或证据不足时保留未决，提出建议。不能用差异、issue、注释或通用 JSON
保留本身，证明对应类型化 API 有误；也不顺带授权其他契约迁移。

The proposed default-accurate/error-reporting plus optional compatibility mode remains
unapproved. This conditional rule is not approval of that design, a baseline upgrade,
control development, real-device operations or Mooncakes publication.

该原则不是对兼容模式设计、升级基准、控制开发、实机或发布的批准。

## Fixed comparison inputs / 固定参照

The requested repositories resolve to the following canonical DMTF repositories. These
are fixed source snapshots, not substitute release-package version claims.
[Eight same-input numeric observations](OFFICIAL-NUMBERS-01.md) now provide runtime evidence
for the listed generic entry points, with typed-field coverage limits:

| Reference | Commit checked on 2026-11-11 | Evidence currently available |
| --- | --- | --- |
| [GoFish v0.27.0](https://github.com/stmcginnis/gofish/tree/4cc897fb5c172996e8f34a31a5d1012b45a287a7) | `4cc897fb5c172996e8f34a31a5d1012b45a287a7` | Existing typed loopback differential reports |
| [DMTF/Redfishtool](https://github.com/DMTF/Redfishtool/tree/8c46f567aa9c960851108e43bf23fd6a64c37897) | `8c46f567aa9c960851108e43bf23fd6a64c37897` | Real CLI raw GET on eight exact numeric fixtures; generic JSON results recorded |
| [DMTF/libredfish](https://github.com/DMTF/libredfish/tree/f9a23c33d46afe15f09b604160c09a320f1c769c) | `f9a23c33d46afe15f09b604160c09a320f1c769c` | Unmodified shared library built and executed: eight same-byte payload/accessor probes, without HTTP |

Redfishtool's reviewed response path uses json.loads on response text. libredfish's
reviewed payload entry uses Jansson json_loads and offers distinct integer/long-long/double
accessors. Those generic entry points do not by themselves choose a GoFish typed field's
range, coercion, default or failure contract. The numeric report records the exact entry points; further runs must record their
dependency/runtime versions and returned type/value/error; do not infer agreement from
similar names or replace one official library with a hand-written imitation.

已审阅的入口分别使用 Python JSON 和 Jansson；通用 JSON 入口不自动决定 GoFish 类型化
字段的范围、转换、默认值或错误契约。后续须记录真正调用的官方入口、依赖版本、类型、
值与错误，不以手写仿真代替官方实现，不从名称相似推断一致。

Sources: [Redfishtool transport](https://github.com/DMTF/Redfishtool/blob/8c46f567aa9c960851108e43bf23fd6a64c37897/redfishtoollib/redfishtoolTransport.py),
[libredfish payload implementation](https://github.com/DMTF/libredfish/blob/f9a23c33d46afe15f09b604160c09a320f1c769c/src/payload.c),
[payload API](https://github.com/DMTF/libredfish/blob/f9a23c33d46afe15f09b604160c09a320f1c769c/include/redfishPayload.h).

## Public registry / 公开登记

**No verified exception yet.** Current implementations retain their existing contracts;
known differences remain P/U and no row becomes V through this policy alone. An exception
must include a stable ID, exact input/operation, all pinned versions, GoFish and both DMTF
results, the defect rationale/official basis, chosen behavior, code/tests, affected scope,
remaining limitations and links to the reproducible evidence. Preserve prior observations
and distinguish approved-exception conformance from literal GoFish equivalence.

**目前没有已核实例外。** 条目须公开稳定编号、确切输入/操作、各版本、三方结果、错误
判断与官方依据、采取的行为、代码/测试、影响范围和限制。原有差分证据保留；符合获准
例外与字面 GoFish 一致必须分开报告，不能由本原则直接将 P/U 转为 V。

| Candidate, not established / 尚未成立的候选 | Existing observation | Missing evidence / 待补证据 | Next recommendation / 后续建议 |
| --- | --- | --- | --- |
| PCIe LanesInUse `16777217` | Go 16777216; native exact 16777217 (batch 03) | Both generic paths now retain 16777217; comparable typed-field/domain validation is unestablished / 通用保留已测，同形字段与语义域仍未核实 | Prioritize exact-value preservation verification; do not copy float32 loss before the gate / 优先核实精度，不先复制损失 |
| PCIe lane `"not-a-number"`, true, or 1.5 | Go 0/0/1; native errors (batch 03) | Both generic paths retain original type/value; getters differ. Typed vendor validation/coercion is unestablished / 通用路径保留原值，getter 不同，厂商字段转换未覆盖 | Separate vendor coercion from transport/raw reads; retain D-VENDOR-NUM / 区分厂商转换与通用读取 |
| Missing/null/default and null list elements | Recorded in batches 01–08 | Comparable typed contracts may be absent; untested / 是否有可比较的类型化契约仍未核实 | Do not treat generic JSON preservation as mandatory scalar-default behavior / 不由 JSON 保留推导标量默认值 |
| Task Payload wrong type, PercentComplete range/spelling | Exact batch 05 cases | PercentComplete generic reads/accessors measured; field validation and Payload malformed-type behavior remain unverified / 进度通用读取已测，字段校验及 Payload 类型错误仍未核实 | Separate selected-field parsing from whole-model validation and API representation / 区分局部解析、全模型验证与类型表示 |
| #516 ETag/Boot target and #582/#583 expansion | Source review in ISSUES.md | Mutation behavior is outside authorized read-only work; expand is untested / 控制未授权，expand 未测 | Keep source findings and version boundaries; no unsafe reproduction or silent baseline change / 保留版本事实，不越界复现 |


[ActionInfo routing review](ACTION-INFO-ROUTING-01.md): two GoFish GET-only cases reproduce
insert-link selection by EjectMediaActionInfo and unsupported status when only an eject link
exists. Both pinned DMTF source audits lack an established comparable VirtualMedia selector.
This fails the current evidence gate; no verified exception or convenience-method fix follows.

两个弹出 ActionInfo 场景已复现；双 DMTF 可比较选择器仍未覆盖，门槛未满足，不由通用
URI/节点查询推导官方修复契约，不宣布例外或新增该便捷方法的兼容实现。
