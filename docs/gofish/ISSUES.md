# Upstream issue review / 上游 issue 审阅

Checked 2026-11-11 against public GitHub issue/PR state and the pinned GoFish v0.27.0
source (`4cc897fb5c172996e8f34a31a5d1012b45a287a7`). Issue descriptions are reports or
proposals, not proof that the pinned version has exactly that behavior. This review
neither changes the baseline nor approves compatibility/security/control contracts.

2026-11-11 核对公开 issue/PR 与固定源码。issue 描述属于报告或提案，不能直接当作固定
版本的运行事实；本审阅不升级基线、不批准兼容、安全或控制契约。

| Issue / state at review | Pinned source and current relevance / 固定版本与当前关联 | Evidence and disposition / 证据与处理 |
| --- | --- | --- |
| [#516](https://github.com/stmcginnis/gofish/issues/516), open | Entity.Headers includes its own ETag without a target URI argument. However SetBoot already tries the System PATCH then falls back to Settings, fetching its ETag and sanitizing it. Thus “ignores Settings” is not an exact description of v0.27.0 / ETag 目标问题仍需审阅，但 SetBoot 已有先主资源后 Settings 的回退，不能照抄 issue 结论 | **Source only for mutations.** New `issue_current_boot_settings` checks reading current Boot while retaining Settings and both-resource distinction, with no implicit Settings GET/write. SetBoot/ETag concurrency stays behind D-CONTROL / 写入仅源码审阅；读取场景通过，控制继续待决 |
| [#451](https://github.com/stmcginnis/gofish/issues/451), open proposal | Broad relaxed decoding is proposed, not a universal v0.27.0 contract. PCIeInterface already has specific coercions / 通用宽松解码是提案，PCIe 局部转换则已存在 | Existing batch 03 measures strings, bool, fraction and float32 loss. Keep D-VENDOR-NUM/D-JSON open; do not silently broaden decoding / 复用既有实测，不整体放宽 |
| [#483](https://github.com/stmcginnis/gofish/issues/483), open | Entity has top-level `@Message.ExtendedInfo`; arbitrary `Field@Message.ExtendedInfo` lacks the proposed generic typed map. These are distinct from error-body ExtendedInfo / 根级、逐属性与错误正文扩展信息不同 | New `issue_property_annotations_raw` preserves root/property annotations and OEM in native parsed JSON and Go ComputerSystem.RawData. No typed per-property API claim; that remains U / 已测原始数据保留，类型化能力仍缺失 |
| [#428](https://github.com/stmcginnis/gofish/issues/428), open | RawData availability varies by Go type; ComputerSystem, BootOption and SecureBoot expose it, while Entity is not a universal raw-data container / 各类型公开原始数据能力不同 | Same synthetic raw case plus native raw-retention tests. Native Resource.json/Boot.json preserve parsed data, not original byte encoding. Go update-diff/RawData APIs remain separate gaps / 语义 JSON 保留不等于字节或更新差分兼容 |
| [#295](https://github.com/stmcginnis/gofish/issues/295), open | Proposal concerns dump grouping/customization. Pinned client uses DumpRequestOut(req,true) and DumpResponse(resp,true); headers and bodies can include credentials or private values / 提案讨论 dump 分组，固定实现可能输出认证头和正文 | **Source-only risk**, not a reproduced leak. No dump API added; adapters never enable DumpWriter. Existing mock checks diagnostic redaction. Any future debug API needs an explicit redacted contract, not reproduction of secret-bearing dumps / 不照搬敏感输出，不用真实凭据复现 |
| [#567](https://github.com/stmcginnis/gofish/issues/567) / [#568](https://github.com/stmcginnis/gofish/pull/568), closed/merged | TLSClientConfig cloning fix is included in v0.27.0 / TLS 配置克隆修复已在基线 | Source and ancestry checked. Native client keeps verified trust configuration and has no Insecure switch. Existing trust/mismatch tests apply; no new claim of shared-config race equivalence / 复用 TLS 测试，不冒称并发隔离全部验证 |
| [#572](https://github.com/stmcginnis/gofish/pull/572), merged | Iterative pagination cycle detection is included in v0.27.0 / 分页循环修复已在基线 | Existing test_gofish loop case and native/mock cycle tests cover rejection. Go valid collections remain uncapped; native page/member budgets still differ / 循环拒绝已有证据，数量预算仍有差异 |
| [#582](https://github.com/stmcginnis/gofish/pull/582), merged after baseline | Sticky expand fallback across later pages is absent from v0.27.0 / 后续页保持 expand 回退状态的修复不在基线 | **Source/ancestry only.** Current adapters disable AutoExpand and native has no automatic expand/retry. Existing paged tests do not validate this behavior / 不把普通分页通过当作 expand 一致 |
| [#583](https://github.com/stmcginnis/gofish/pull/583), merged after baseline | BuildQuery joins existing query with another `?` when expand is enabled in v0.27.0; later fix uses existing query/expand handling / 基线在已有查询后再拼接问号，后续才修复 | **Source/ancestry only.** Boot/signature fixtures preserve `$skip` with expand disabled. Supporting query options or adopting the later fix requires an explicit contract/baseline choice / 保留已测查询，不擅自加入选项或升级基线 |

The two new read cases are in [batch 04](READONLY-04.md) and its
[machine-readable report](readonly-04.json). They use only synthetic values. No upstream
control call, dump, real hardware request or authentication downgrade was executed.

新增两个定向读取场景与完整请求轨迹均在 batch 04；未执行上游控制、dump、实机请求或
认证降级。其余条目明确区分源码证据和已运行测试，未验证项不标记一致。

## Version boundaries / 版本边界

GitHub ancestry comparisons of merge commit → pinned baseline confirmed:

| PR | Merge commit | Merged (UTC) | Baseline relationship |
| --- | --- | --- | --- |
| #568 | `761705c0e34ce31c08b617d236131b1d3679aabc` | 2026-09-09 | Baseline ahead by 6 commits; included / 已包含 |
| #572 | `d20d0435b3b4f56cab7462ea357d86198c5d8d2a` | 2026-09-17 | Baseline ahead by 3; included / 已包含 |
| #582 | `84c39cff2174b3fb9b3033d782beb1ff201dd4e6` | 2026-11-01 | Baseline behind by 13; excluded / 未包含 |
| #583 | `49cbdff1476390e64105923f0e5bc2ffb8f34522` | 2026-10-21 | Baseline behind by 6; excluded / 未包含 |

Pinned source: [client TLS/dumps](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/client.go),
[entity headers/ExtendedInfo](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/entity.go),
[SetBoot/RawData](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/computersystem.go),
[page walker](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/collection.go),
[BuildQuery](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/odata.go).

The user's subsequently confirmed [two-DMTF exception rule](EXCEPTIONS.md) governs
suspected GoFish defects. The issue review alone does not satisfy that gate. [Numeric runtime checks](OFFICIAL-NUMBERS-01.md)
now exercise eight inputs at generic official entry points; equivalent typed validation and
other cases remain unverified. No exception is declared by this table.
用户后续确认的双 DMTF 原则适用于疑似缺陷；已有八个通用入口实测，但同形类型化校验
及其余场景仍未核实，不把 issue/source 审阅或局部实测当成例外成立。

## Recommendations awaiting decision / 待裁决建议

Keep the existing strict/exact/error-reporting behavior while the user reviews the proposed
optional GoFish compatibility mode. Define scalar defaults, coercions, inline selection and
error/partial-result mapping separately. A compatible profile must say which reference
quirks it reproduces and which explicit exceptions leave full parity open. Debug output
should redact credentials and private bodies; any retained safety exception must be visible
in acceptance. Do not replace the v0.27.0 oracle with latest main without approval.

建议在用户裁决前保留现契约；默认值、转换、内嵌选择及错误/部分结果逐项定义。兼容模式
需明确复刻哪些行为、保留哪些例外，不能将例外标成完整一致。调试输出建议脱敏认证信息
和私密正文，相关安全例外应进入验收；未经决定不把 latest main 替换为基准。


<a id="virtual-media-actioninfo-source-candidate"></a>
## Virtual-media ActionInfo source candidate / 虚拟介质源码候选

During batch 07, the pinned [EjectMediaActionInfo implementation](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/virtualmedia.go#L278)
was found to check and fetch `v.insertMedia.ActionInfoTarget`, as does InsertMediaActionInfo.
For distinct advertised insert/eject ActionInfo targets, that source selects the insert
metadata for the eject-named method. This is source inspection only, not a numbered upstream
issue, executed comparison, latest-main claim or verified defect exception. Neither DMTF
reference was exercised for this behavior. Batch 07 implements no ActionInfo convenience
method and issues no ActionInfo or control requests. Keep this candidate for the future
read-metadata batch and the user's two-reference gate; do not preselect a workaround.

固定版 EjectMediaActionInfo 检查并读取 insertMedia.ActionInfoTarget，两个广告链接不同
时源码将选择 insert 元数据。这里只记录源码事实：不冒充已报告 issue、实际差分、最新版
行为或已核实例外。双 DMTF 未核验；本批未实现对应便捷方法，也未发出元数据/控制请求。
后续读元数据批次按既有门槛处理，不先决定修复方式。
