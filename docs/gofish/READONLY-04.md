# Boot and Secure Boot reads / 启动配置与安全启动读取

Read-only batch 04 · 2026-11-11 · GoFish v0.27.0 at
`4cc897fb5c172996e8f34a31a5d1012b45a287a7`.
The existing Field and strict-decoding contract is unchanged. The proposed accurate/error
by default plus optional GoFish compatibility mode is **awaiting a user decision**;
no profile, default migration or compatibility exception is approved or implemented.

本批沿用 Field 三态与严格解码。默认准确且明确报错、另提供 GoFish 兼容模式的建议仍待
用户决定；本批不预设结论，不引入模式开关、默认值迁移或兼容例外。

## Implemented reads / 已实现读取

| API | Selected behavior / 选定行为 |
| --- | --- |
| `Resource::boot()` | ComputerSystem.Boot as Field[Boot]; ordered boot lists, next choice, override/retry/fault/trusted-module policy strings, HTTP URI and allowable-value annotations / 启动列表、下次选择、覆盖与策略字符串、HTTP URI 和允许值注解 |
| `Resource::boot_option()` | Alias (`boot_alias`), reference, display name, UEFI path, enabled / 别名、引用、显示名、UEFI 路径及启用标志 |
| `Resource::secure_boot()` | Current boot state, next-boot enablement and mode kept separate / 分别保留当前状态、下次启动启用配置与模式 |
| `Resource::secure_boot_database()` | DatabaseId / 数据库标识 |
| `Resource::signature()` | Signature string, type, registry and UEFI owner / 签名内容、类型、注册表及所有者 |
| `Client::boot_options(system)` | Explicit nested Boot.BootOptions collection / 仅跟随嵌套集合链接 |
| `Client::secure_boot(system)` | Explicit ComputerSystem.SecureBoot singleton / 系统的显式单资源链接 |
| `Client::secure_boot_databases(secure.resource)` | Advertised database collection / 显式数据库集合 |
| `Client::signatures(database.resource)` | Advertised signature collection / 显式签名集合 |

The five views add 14/5/3/1/4 selected property mappings. Boot retains its complete nested
JSON; the four resource views retain Resource. Lists preserve order and duplicates;
unknown enum strings remain strings. BootOrder does not reorder the BootOptions collection.
HTTP/UEFI paths and signature strings are data: parsing them neither fetches a boot image,
validates a signature nor applies configuration. Reported Secure Boot flags are not a
security attestation. Existing SystemInfo decoding is unchanged.

五个视图分别增加 14、5、3、1、4 个属性映射，保留完整原始 JSON。启动列表保留顺序和
重复，未知枚举字符串原样保留；BootOrder 不用于重排 BootOptions 集合。HTTP/UEFI 路径
与签名内容只作为数据，不下载镜像、不验签、不应用配置；报告的标志不构成安全证明。

Navigation reuses bounded singleton/collection reads: same-origin root-relative paths,
per-call byte/time/member limits, collection page/cycle limits and duplicate suppression.
Missing/null keep their Field states. No implicit recursive enumeration is added.
The offline extended example prints only synthetic counts/presence; callers control
whether to expose private raw data, identifiers, boot URIs or signature contents.

导航复用既有有界读取，每次调用有时限、字节和成员预算，集合有分页与循环限制，链接
去重；不隐式递归枚举。离线示例只打印合成数量与存在性，原始数据的输出由调用方管理。

## Exact limits / 明确边界

Reference source headers are ComputerSystem.v1_27_0 (2025.4), BootOption.v1_0_6 (2017.3),
SecureBoot.v1_1_2, SecureBootDatabase.v1_0_3 and Signature.v1_0_3 (the latter three 2020.1).
These identify the reference files; they are not a claim of complete schema conformance.
AutomaticRetryAttempts/RemainingAutomaticRetryAttempts, RelatedItemCount/RelatedItem,
certificate collections, all enum constants, typed per-property ExtendedInfo, update
serialization, boot setters, ResetKeys and certificate/key enrollment remain open.
No numeric API decision is required by these selected string/bool/list fields.

参考文件版本如上，不冒称完整 schema 符合性。重试次数、关联项计数及读取、证书集合、
完整枚举、逐属性扩展信息类型化、写入序列化、启动设置、密钥重置和证书/密钥登记继续
保留为差距。本批选定字符串、布尔和列表字段，不依赖数值类型迁移决策。

## Differential evidence / 差分证据

```sh
moon run examples/extended --target native
python3 tools/test_boot.py
python3 tools/test_boot.py --report /tmp/boot-evidence.json
```

[The raw report](readonly-04.json) records exact synthetic inputs,
complete selected projections, request traces, item IDs and fixture/source hashes. The
source hashes plus subject_base_commit identify the tested batch. It compares both GoFish
BootOptions entry points against the single native reader. Arrays are not sorted away;
concurrent member GET order is recorded, while request multiplicities and result order
are asserted. The runner asserts explicit expectations. Both clients use fresh loopback fixtures
with GET-only access.

35 cases cover defined values, ordering/duplicates, unknown enums, missing/null, wrong
types, four navigations, pagination, inline data, denial/empty collections and two issue
regressions. Fourteen selected observations agree, four both reject with different error
categories, and seventeen differ. All 43 native tests, mock integration, release build,
format/API generation and package-list checks passed locally on macOS arm64. Linux CI
runs the same differential suite. **These observations do not establish whole-model parity.**
42 declarations gain candidate mappings: **353 P / 11,227 U / 0 V**.

35 场景涵盖有值字段、顺序/重复、未知值、三态、类型错误、四条导航、分页、内嵌数据、
拒绝/空集合及两个 issue 定向场景。14 个选定观测相同，4 个两端拒绝但错误分类不同，
17 个有差异；本地 43 项 native、mock、构建、格式/API 生成和打包清单检查通过。
新增 42 个候选映射，仍为 353 P / 11,227 U / 0 V，不宣称整体一致。

| Input / 输入 | GoFish | moonredfish | Impact / 影响 |
| --- | --- | --- | --- |
| Missing/null Boot | Zero-valued Boot | Missing/Null | Presence/default mapping / 存在性与默认值不同 |
| BootOrder `[null]` | `[""]` | InvalidResponse | Invalid entry may become an empty boot reference / 无效条目可能变成空引用 |
| SecureBootCurrentBoot `Enabled`, SecureBootEnable `false` | Both retained | Both retained | Current and next are distinct; no derived boolean / 当前与下次不同，不推导布尔值 |
| SecureBoot inline current `Enabled`, linked resource current `Disabled` | Uses inline data, no target GET | GET target, returns `Disabled` | Observation and request count differ / 观测与请求次数不同 |
| Absent BootOptions link through either Go getter | nil, no member GET | Missing, no member GET | Return-shape difference only in this fixture / 此夹具仅返回形态不同 |
| Signatures collection 403 | nil plus CollectionError | HTTP error, no array | Error/result contract differs / 错误与结果契约不同 |
| Empty Signatures Members | nil | Value([]) | Empty versus absent representation / 空与缺失表示不同 |

The two issue cases retain BootNext@Message.ExtendedInfo/OEM/raw JSON and keep current
Boot separate from an advertised Settings resource with different BootNext and ETag.
They assert no Settings GET or action request. Raw retention is semantic parsed JSON,
not a byte-preserving export or a typed annotation API. See [issue review](ISSUES.md)
for the pinned-version correction to #516 and fixes before/after v0.27.0.

两个 issue 场景验证扩展信息/OEM/原始 JSON 保留，以及当前 Boot 不被 Settings 中不同的
值与 ETag 替换；断言未读取 Settings 或调用动作。保留解析后的语义 JSON，不等于字节
原样导出或类型化注解 API。完整缺陷关联和版本边界见 issue 审阅。

All unresolved default, strictness, inline and error choices stay in the
[combined decision review](DECISIONS.md). No real device, control operation or publication.

Sources: [ComputerSystem/Boot](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/computersystem.go),
[BootOption](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/bootoption.go),
[SecureBoot](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/secureboot.go),
[SecureBootDatabase](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/securebootdatabase.go),
[Signature](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/signature.go).
