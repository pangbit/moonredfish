# Certificate inventory reads / 证书清单读取

Read-only batch 06 · 2026-11-11 · GoFish v0.27.0 at
`4cc897fb5c172996e8f34a31a5d1012b45a287a7`.

This batch connects certificate inventory to the existing System, Boot and Secure Boot
database readers, and adds certificate-service/location discovery. Certificate text,
identities, usage, validity strings and fingerprints are reported metadata. Nothing here
parses X.509, verifies a signature or trust chain, installs trust, generates keys/CSRs,
enrolls, replaces, rekeys or renews a certificate.

本批接通系统、Boot 和安全启动数据库的证书清单，并加入证书服务与位置发现。证书正文、
身份、用途、有效期字符串和指纹仅作为报告数据；不进行 X.509/签名/信任链验证，不安装
信任、不生成密钥/CSR，也不登记、替换、换钥或续期。

The existing Field/strict-decoding contract is unchanged. Compatibility decisions remain
open. The user-approved [two-DMTF defect gate](EXCEPTIONS.md) now has a separate
[eight-input numeric runtime report](OFFICIAL-NUMBERS-01.md); no typed-behavior exception
is inferred from those generic observations or from this certificate batch.

三态与严格解码不变，兼容取舍未决。双 DMTF 规则已补充独立数值实测，但不将通用读取
观测或本批证书测试当作已核实的类型化行为例外。

## Public API / 公开 API

| API | Input and behavior / 输入与行为 |
| --- | --- |
| `Resource::certificate()` | 14 selected certificate fields, including nested issuer/subject and selected Health / 14 个选定属性，含签发者、主体和健康 |
| `CertificateIdentifier` | 8 strings and 4 ordered string arrays; complete nested JSON retained / 8 个字符串、4 个有序数组及嵌套原始 JSON |
| `Client::certificate_service(root)` | ServiceRoot.CertificateService singleton as Resource / 服务根单链接，返回 Resource |
| `Client::certificate_locations(service)` | CertificateService.CertificateLocations singleton as Resource / 位置单链接，返回 Resource |
| `Client::certificates(owner)` | Owner.Certificates collection; compared through System and SecureBootDatabase / 顶层集合，已对照系统与安全启动数据库入口 |
| `Client::boot_certificates(system)` | Nested ComputerSystem.Boot.Certificates only / 仅沿嵌套 Boot 集合 |
| `Client::certificate_location_certificates(locations)` | CertificateLocations.Links.Certificates array / 位置的显式链接数组 |
| `Client::certificate_subjects(certificate.resource)` | Certificate.Links.Subjects array once / 读取一次主体证书数组，不递归链路 |

Certificate exposes CertificateString, CertificateType, CertificateUsageTypes, Fingerprint,
FingerprintHashAlgorithm, Issuer, KeyUsage, SerialNumber, SignatureAlgorithm, Status,
Subject, UefiSignatureOwner, ValidNotAfter and ValidNotBefore. Identifier exposes City,
CommonName, Country, DisplayString, Email, Organization, OrganizationalUnit, State,
AdditionalCommonNames, AdditionalOrganizationalUnits, AlternativeNames and DomainComponents.
All use Field; unknown strings, case, separators, list order and duplicates are retained.
The library does not infer issuer identity from a link or derive dates/fingerprints from PEM.

全部属性使用三态；字符串大小写、分隔符、未知值、列表顺序和重复均保留。不从链接推导
签发者，不解析 PEM 来生成有效期或指纹。Subject 与 Issuer 分别保留，不合并身份。

Singleton/collection/array reads reuse the existing path restrictions and per-call byte,
time and member budgets. Collections retain page/cycle limits; link arrays validate all
paths before member GETs and deduplicate by first occurrence. Top-level Certificates and
Boot.Certificates are independent sources. Multiple public calls have separate budgets.
Service and location results are generic Resource views, not complete typed models.

导航复用既有路径与预算限制；链接数组先校验后请求并按首次出现去重。顶层与 Boot 证书
来源不混用；多次调用分别计预算。服务与位置返回通用 Resource，不宣称完整类型化模型。

Certificate bodies/identifiers remain caller data and can be private. The offline example
prints only synthetic presence/counts. Raw JSON is retained even for unselected fields;
that is neither a byte-preserving export nor automatic redaction or authorization.

离线示例只打印合成数量/存在性。证书正文和标识的输出由调用方管理；原始 JSON 保留
未选定字段，不等于字节原样导出、自动脱敏或操作授权。

## Verification and differences / 验证与差异

```sh
moon run examples/extended --target native
python3 tools/test_certificate.py
python3 tools/test_certificate.py --report /tmp/certificate-evidence.json
```

[Raw evidence](readonly-06.json) includes exact inputs, complete selected projections,
errors, request traces, item IDs and source/fixture hashes. The runner asserts independent
expected results and request multiplicities; it preserves returned source order and records
GoFish's concurrent GET order. All fixtures are synthetic GET-only numeric loopback servers.
The source hashes plus subject_base_commit identify the tested implementation.

30 cases cover metadata/identities, missing/null/empty values, unknown strings, malformed
selected fields, unselected SPDM decoding, six navigations, pagination, source separation,
inline data, duplicate links, prevalidation and partial results. Eleven selected observations
agree, three both reject with different categories and sixteen differ. All 49 native tests,
mock integration and release build passed locally on macOS arm64. Linux CI runs the
certificate comparison alongside the existing suites. **36 new candidates produce
423 P / 11,157 U / 0 V**, not complete certificate or GoFish equivalence.

30 场景中 11 个选定观测相同、3 个两端拒绝但错误不同、16 个有差异。本地 49 项 native、
mock 和 release 构建通过；Linux CI 执行同一对照。新增 36 个候选，总计
423 P / 11,157 U / 0 V，不以数量或部分字段相同冒称完整一致。

| Exact input / 确切输入 | GoFish | moonredfish | Consequence / 影响 |
| --- | --- | --- | --- |
| Issuer absent/null | Zero-valued identifier | Missing/Null | D-PRESENCE |
| KeyUsage or AlternativeNames `[null]` | `[""]` | InvalidResponse | D-JSON |
| CertificateString empty or synthetic non-PEM text | String retained | String retained | No cryptographic validity claim / 不是有效证书判定 |
| ValidNotBefore `future-format` | String retained | String retained | No date interpretation / 不解释日期 |
| SPDM `"not-an-object"` | Typed Certificate GET fails | Selected fields remain readable; raw retained | Eager versus selected-field validation / 整模型与局部解析不同 |
| Inline service/location name differs from linked resource | Uses inline data, no GET | Fetches linked data | B06 / D-COLLECTION |
| Location certificate array `[C0,C0]` | Two results/GETs | One result/GET | Duplicate contract / 去重不同 |
| Database collection `[C0,403]` | C0 plus CollectionError | HTTP error without an array | Partial-result contract / 部分结果不同 |

No behavior choice above is silently resolved. The [combined review](DECISIONS.md)
retains these decisions and the [upstream issue record](ISSUES.md) remains in place.

## Remaining scope / 剩余范围

SPDM typed slot data, password/write-only properties, full Status, complete service and
location types, automatic enrollment, certificate enrollment objects, CA-enrollment links,
all enum constants, update serialization and actions remain gaps. The pinned Certificate
stores a private issuer link but has no exported issuer-navigation method; this batch adds
no guessed issuer-chain API. Metadata Subject/Issuer are distinct from Links.Subjects.

SPDM、写入字段、完整服务/位置模型、自动登记、CA 登记链接、完整枚举及序列化/动作仍未
实现。固定参考保存私有 issuer 链接但无公开导航方法，本批不猜测新增链路。元数据身份
与 Links.Subjects 不混为一谈。无实机操作或 Mooncakes 发布。

Reference headers: [Certificate.v1_11_0 / 2025.3](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/certificate.go),
[CertificateService.v1_2_1 / 2025.3](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/certificateservice.go),
[CertificateLocations.v1_0_4 / 2018.3](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/certificatelocations.go).
