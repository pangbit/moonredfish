# GoFish parity plan / GoFish 完整对齐计划

**Open contract — 2026-11-11. Read-only differential work and unambiguous fixes authorized.**
**持续推进只读差分与无歧义修复；跨语言 API、安全和重大兼容取舍仍待明确决策。无实机控制或发布。**

[Read-only batch 01 / 只读证据 01](gofish/READONLY-01.md): 39 measured cases,
22 known differences, one integer-validation defect fixed.
[Read-only batch 02 / 只读实现 02](gofish/READONLY-02.md) adds DHCP/DNS/SLAAC/policy
read fields. Current mappings: 263 P / 11,317 U / 0 V; no fully verified items.

The target is every public capability of the fixed GoFish version, including Redfish,
Swordfish, OEM extensions and support APIs. Current moonredfish is a selected read-only
subset with known behavior differences. It is **not fully equivalent**. Nothing below
converts existing subset tests into proof of complete parity.

目标为固定版本 GoFish 的全部公开能力，包括 Redfish、Swordfish、OEM 与辅助 API。
当前 moonredfish 仅实现选定只读子集，且存在明确行为差异，**不能称为完整一致**。
未映射、未验证、权限不足或缺少硬件的条目都保持未完成；不以“暂不支持”关闭差距。

## 1. Fixed baseline / 固定基线

| Item / 项目 | Baseline / 基线 |
| --- | --- |
| Reference client / 参考客户端 | GoFish **v0.27.0**, commit [`4cc897fb5c172996e8f34a31a5d1012b45a287a7`][tag]; tag verified against GitHub on 2026-11-11 |
| Module integrity / 模块完整性 | `h1:jyM2BlBhULXtHnayY+/wnkZYXKjIO0ZdR3oBXKl1VYs=`; existing `tools/gofish/go.mod` / `go.sum`; `go mod verify` passed |
| Subject / 被对齐版本 | moonredfish [`b10066cb3d382f74489bce18513be1d0fe284ed7`][subject] |
| Reference execution / 参考执行环境 | Go 1.24.0 for existing comparisons; GoFish declares `go 1.21`. Record exact compiler/OS/architecture for every future result; declared minimum is not a proof that all platform/toolchain combinations work |
| MoonBit execution / MoonBit 环境 | Native compiler `0.10.20+65efd5b93`, moon `0.1.20261104`, `moonbitlang/async` 0.22.1 |
| Protocol review baseline / 协议审阅基线 | **DSP0266 1.23.0**, explicitly referenced by GoFish's task-monitor implementation; [official specification][protocol]. Earlier moonredfish protocol review used 1.20.1 and does not establish 1.23.0 coverage |
| Data models / 数据模型 | Exact schema URI/version from each pinned source file, recorded in the item matrix. Source headers span multiple releases through **2025.4**; there is no single shared resource schema version |
| Swordfish / Swordfish 模型 | Exact versions from source, including `Volume.v1_10_2`, `StorageService.v1_7_0`, `StoragePool.v1_9_2`; companion `SF*` and other headerless types remain in scope |
| Existing public fixture / 既有公开夹具 | DMTF mockups commit `23d21f9a3610f6b6fbb71ffc941296b159a524d2`; sample version is separate from protocol/schema/client versions |

No floating `latest` baseline. Updating GoFish, its schemas, Go/MoonBit or async requires
an explicit baseline change and inventory diff. GoFish behavior is the compatibility
reference; DMTF/SNIA documents explain model/protocol intent. When they disagree, record
the conflict and obtain a decision instead of silently changing the oracle.

不追随浮动 latest。升级参考客户端、schema 或工具链须重新记录版本及差异。GoFish 的
实际行为是兼容性参照，DMTF/SNIA 规范用于解释意图；两者冲突时明确记账并决策，不暗换标准。

## 2. Complete declaration inventory / 全量声明盘点

Deliverables / 交付物：

- [File matrix / 253 文件矩阵](gofish/MATRIX.md): every scanned importable source file,
  domain, counts, current state and initial work phase.
- [Item matrix / 逐项矩阵](gofish/api-v0.27.0.json): each declared exported type,
  function, method, field, constant, variable and interface method, plus embedding
  relationships; exact signature summary, source line, source SHA-256, mapping candidate
  and acceptance template. Stable row ID: `package::kind::name`.
- [Read-only AST inventory tool / 只读 AST 盘点工具](../tools/gofish_inventory.go): parses
  source without executing GoFish or contacting a device.
- [GoFish BSD-3-Clause notice / 上游许可](gofish/GOFISH-LICENSE): the API index contains
  upstream identifiers/declaration summaries; no upstream implementation bodies are vendored.

| Importable package / 可导入包 | Files | Types | Functions + methods |
| --- | ---: | ---: | ---: |
| `github.com/stmcginnis/gofish` | 2 | 7 | 65 |
| `schemas` | 214 | 1,071 | 1,858 |
| `oem/ami` | 4 | 21 | 9 |
| `oem/dell` | 7 | 26 | 20 |
| `oem/hpe` | 1 | 4 | 2 |
| `oem/smc` | 24 | 37 | 95 |
| `oem/zt` | 1 | 3 | 3 |
| **Total / 合计** | **253** | **1,169** | **2,052** |

Also indexed: **5,590 exported fields, 2,494 constants, 5 variables, 20 interface-method
signatures and 250 embedding relationships**. These total 11,330 declared exported items
plus 250 embeds, not 11,580 independent features. Promoted members are resolved through
the embed rows and their declaring types, not duplicated as new features. Imported Go
runtime types (`http.Response`, `context.Context`, channels, reflection, callbacks) require
an approved MoonBit API translation under D-API below.

另列 5,590 个字段、2,494 个常量、5 个变量、20 个接口方法和 250 个嵌入关系。
这些是声明规模，不是功能数量或完成率。嵌入提升的字段/方法通过关系追溯原声明；涉及
Go 标准库、context、channel、反射和回调的接口，必须先确定 MoonBit 等价形态。

The scan includes public test helpers such as `schemas.TestClient`, deprecated aliases,
legacy and modern models, and all five OEM packages. It excludes `_test.go`, example
`main` programs and hidden build tooling because they are not imported library APIs.
File hashes cover the original source including private implementation bodies, but an AST
index does **not** prove all runtime paths have been semantically audited. Future behavior
findings remain open matrix cases; unknown behavior is never inferred to be equivalent.

公开测试辅助 API、弃用别名、新旧模型和五组 OEM 均纳入；只排除非库 API 的测试文件、
示例程序和隐藏构建工具。源码哈希覆盖文件完整内容，但全量声明盘点不等于穷尽运行时行为。
尚未审阅的分支保留为未知，不能按名字相似判为一致。

States / 状态：`U` = no reviewed full mapping (gap/unverified); `P` = overlapping subset
or mapping candidate; `V` = verified under an approved contract. Initial inventory has
234 `P` and 11,346 `U` rows, including embeds, and **zero `V`**. A `P` field may have a
selected-value test, but is not equivalent across null/default/error/serialization cases.
Initial statuses refer to the subject baseline; later candidate mappings are versioned
by the evidence batches. Current totals are 263 P / 11,317 U / 0 V after batch 02.
They are not a claim about untested behavior or future work.

`U` 是未映射差距/未验证，`P` 是已有子集或映射候选，`V` 才表示按已批准契约验证。
当前无 `V` 项。字段在某个样例中相同，不说明缺失、null、错误、序列化均相同。

## 3. Capability gaps / 能力差距

| Area / 能力域 | GoFish v0.27.0 surface / 参考范围 | moonredfish today / 当前差距 | Work / 阶段 |
| --- | --- | --- | --- |
| Client and transport / 客户端与传输 | Connect variants, custom HTTP client/transport, context, concurrency, pooling, headers, HEAD/GET/POST/PUT/PATCH/DELETE, multipart, dump output | HTTPS + constrained GET and own-session lifecycle; no equivalent raw response/header/transport API; defaults differ | P1; writes gated P4 |
| Auth / 认证 | Anonymous, Basic, session create/delete, imported session/token, session retrieval and clone | Anonymous and own session only; token opaque; discovery, validation and cleanup differ | P1; newly stateful work gated |
| Query and entity / 查询与对象 | `$expand`/levels/fallback, skip/top helpers, embedded resolution, collection concurrency/partial errors, ETag/304 Reload/Refresh, update diff/allowed fields | Pagination/deduplication and bounded link traversal; no query/ETag cache API; raw JSON is not equivalent | P1, P4 |
| Current inventory families / 已有模型 | Full ComputerSystem/Chassis/Manager, Processor/Memory, Thermal/Power, Sensor/Fan/PowerSupply, Storage/Drive/Volume, network, logs, firmware and Bios types/links/actions | Selected fields and selected reads only; remaining properties, links, enums, serialization and actions are gaps | P2, P4/P5 |
| Remaining Redfish / 其余 Redfish | PCIe/CXL/NVMe, fabrics/ports/zones, memory domains, processors/metrics, facilities/cooling/power distribution, batteries, assembly, OS/containers/VM, aggregation/composition/automation, all remaining listed files | No corresponding typed API | P3; actions P4/P5 |
| Schema/registry/security / 模型注册表与安全 | JSON schemas, message/attribute/privilege/feature registries, accounts/roles/external providers, certificates/enrollment, secure boot, keys, licenses, component integrity | Raw access only; no complete typed or control contract | P3, P5 |
| Tasks/jobs/events/telemetry / 任务、作业、事件、遥测 | Task monitor and Retry-After, asynchronous results/channels, job lifecycle, subscriptions and event models, reports/definitions/triggers | Not implemented | P3 reads; P4/P5 mutations |
| BIOS/boot/media / BIOS、启动、介质 | Settings/apply times, password/reset operations, boot updates, virtual-media insert/eject | Current BIOS attributes only | P4/P5 |
| Firmware and diagnostics / 固件与诊断 | SimpleUpdate/start/activate, uploads/multipart, image stores, raw log download, diagnostic actions, clear log | Firmware metadata and log entries only | P3 downloads; P5 mutations |
| Swordfish / 存储管理 | Storage services/pools/groups, replicas/consistency, file systems/shares, class/lines of service, capacity/endpoints, SF companion models and actions | A small Volume projection does not implement Swordfish | P3, P5 |
| OEM / 厂商扩展 | AMI account/event/update; Dell configuration/repository install/jobs/iDRAC monitor/reset; HPE thermal; Supermicro settings/dumps/licenses/uploads; ZT subscriptions/events | No OEM package API | P6 |
| Support API / 辅助 API | Deref/ToRef, link/error/helpers, test client/assertions, deprecated names and exposed interfaces | Different MoonBit helpers; no complete mapping | P1 |

The item index, not this summary table, defines scope. Every file and exported item must
be accounted for; a category called “remaining” is an ordered backlog, not an exclusion.
GoFish's event-management API must not be expanded into an invented built-in event server;
only exported capabilities and their actual behavior are the baseline.

以上是审阅摘要，范围以逐项矩阵为准。“其余”表示待办，不能作为排除理由。也不凭常见
Redfish 功能名称扩充 GoFish 未提供的能力，例如不能假定它包含完整事件接收服务器。

## 4. Known behavioral conflicts / 已知行为冲突

These are verified source-level differences or explicitly pending measurements, not an
exhaustive list of all possible differences. Each B row is a mandatory acceptance case
in addition to the symbol matrix. Sources are pinned, never floating main.

以下已知差异均进入强制验收；尚待实测项明确标识，不能视为已一致。

| ID | Reference behavior / GoFish | Current behavior / moonredfish | Required acceptance / 验收与决策 |
| --- | --- | --- | --- |
| B01 | [Connect][client] immediately reads ServiceRoot, then configures auth | `Client::new` is lazy; login does its own discovery | Request sequence, failure timing and authentication precedence; D-API |
| B02 | [ClientConfig][client] accepts HTTP and optional `Insecure`; custom transports can change behavior | HTTPS verification mandatory; HTTP only explicit numeric loopback | Valid/invalid trust chain, hostname, HTTP, custom CA/client and defaults; D-SAFE |
| B03 | Go `http.Client` and injected client determine redirect/proxy/HTTP2/connection behavior | Per-request async client; redirects rejected, connection closed | Redirect chain, credential propagation, proxy/TLS/keep-alive/context tests with synthetic credentials; D-SAFE. Exact dependency behavior needs differential measurement |
| B04 | No corresponding collection-size/aggregate-byte budgets in [collection traversal][collections]; default HTTP client has no overall request timeout | Mandatory bounded request/operation/response/member/page limits | Boundary/time/cancellation cases; choosing finite limits preserves a difference; D-SAFE |
| B05 | Collections can return successful members plus `CollectionError`, preserve source order, and resolve members concurrently | Fails whole call; deduplicates member links; no partial inventory | Duplicate/failed member, page failure, ordering, concurrency and collection-loop tests; do not sort away an observable difference |
| B06 | Embedded members with an ID can be used directly; expand/fallback can change requests | Retrieves advertised member URI; no auto-expand | Match inline/full/member-link, missing ID, expand depth/failure and request traces |
| B07 | Go structs have scalar zero defaults and pointer/nil fields; [typed model declarations][models] vary by property | `Field` distinguishes Missing/Null/Value | Per-field missing/null/zero/false/empty/unknown-enum cases; approve translated representation under D-API |
| B08 | Native Go integer/uint/float types vary; invalid values depend on each decoder | Selected numeric fields use Double or Int32; phase-two integers capped at 2^53−1 | Exact signed/unsigned bounds, architecture width, fractions and large integers; no rounding or narrowing may be hidden |
| B09 | JSON behavior follows `encoding/json` plus custom unmarshallers | Rejects duplicate keys and invalid UTF-8; selected-field type checks | Duplicate/case-variant keys, invalid UTF-8, malformed/trailing JSON, unknown fields, nested arrays: differential measurement required; do not call either decoder “the same” |
| B10 | [CreateSession][sessions] uses generic POST success handling, reads token/Location and normalizes Location | Requires 201, nonempty valid token and constrained session Location; has discovery fallback | Status 200/201/202/204, missing/malformed headers, absolute/unusual Location, root 401/403; D-SAFE |
| B11 | [Logout][client] returns no error; cleanup failures remain internal; canceled context is replaced | Logout reports errors, handles 401/404 as expiry, retains failures; scoped cleanup has deadline and error precedence | Success/expiry/error/cancel and client reuse tests; D-API/D-SAFE |
| B12 | [Error.Error][errors] can include raw server body; opt-in HTTP dumps contain request/response data | Minimized errors and examples; no equivalent full dump API | Exact structured error/content contract; synthetic secret canaries; D-SAFE |
| B13 | Raw requests accept 200/201/202/204, special 304 sentinel; [Reload/Refresh][entity] preserve cache/ETag behavior | Generic GET accepts 2xx then decodes JSON; no raw response/304 API | Every status class, empty body, headers, 304 identity, 412 and ETag controls |
| B14 | Distinct legacy/modern resource types; subsystem accessors may expose legacy fan/supply types | Some legacy and modern views share MoonBit structs | One-to-one documented type mapping, all properties and resource identity; existing adapter's extra modern GET is not API parity |
| B15 | [Task monitor][tasks] models 202/Location/Retry-After, progress and final response | No task API | Accepted ≠ completed; scripted clock, missing task body, cancel, monitor errors, final resource/header semantics |
| B16 | [Dell ExecuteWithRetry][dell] retries selected failures and optionally resets iDRAC | No automatic control retry/reset | Timeout-after-acceptance/duplicate action cases; explicit decision before copying retry/reset behavior; D-SAFE |
| B17 | Generic update helpers compute diffs, allowed fields, embedded values, ETag headers; actions may use legacy and new task wrappers | No general mutation/update helper | Exact payload omission/null/zero, headers, method/URI, result/error and no unintended replay; P4/P5 gate |
| B18 | User-Agent, default headers, custom headers, raw bodies, multipart boundary and request ordering are observable | Different headers/encoding, fixed request options | D-API defines whether these bytes are part of parity; ignored fields must be approved explicitly, not silently normalized |

A stricter behavior is still a difference. An optional compatibility entry point could
preserve today's strict interface, but would not make the **entire library** behavior
identical. Replacing defaults would affect existing users. Neither design is approved
by this plan; do not implement a second framework before D-API/D-SAFE are decided.

“更严格”仍然是差异。增加兼容入口可保留现有严格接口，但不能因此声称整个库零差异；
替换默认行为又影响现有调用方。本计划不擅自选择其中之一，也不先做双套框架。

## 5. Decisions needed before implementation / 开发前待审核决策

| Decision | Concrete proposal / 建议审核内容 | Consequence / 影响 |
| --- | --- | --- |
| D-REF | Keep GoFish v0.27.0 + exact commit as the full target, including deprecated/public support/OEM APIs | A later version is a separate baseline change, not silent scope growth |
| D-API | Approve **one-to-one MoonBit API translation with equivalent observable semantics**. Map Go pointers/nil, multiple returns/errors, context/channels/callbacks, raw HTTP response/client interfaces and embedding explicitly | Literal Go source/ABI compatibility is impossible for a native MoonBit API. If literal API identity is required, revise architecture to a Go-backed binding; do not call a translation identical |
| D-SAFE | Decide B02–B04/B10–B12/B16/B18 individually: match reference semantics, or retain a documented exception | Any retained exception means the “no differences” target is not met. Compatibility profile/default migration and backward compatibility must be selected explicitly |
| D-PLATFORM | Minimum test environments: existing Linux x86_64 + macOS arm64. Add Linux arm64, macOS x86_64 and Windows x86_64 to the proposed target; assess all other requested Go OS/architecture targets before declaring universal parity | Existing two-platform CI does not imply all Go platforms. Missing build/runtime evidence stays U |
| D-HARDWARE | Approve simulator-based semantic implementation first; keep physical interoperability as a separate pending gate with exact models, firmware, versions and permissions | No physical BMC/storage/PDU access is authorized now. Simulator success cannot satisfy the physical gate |
| D-CONTROL | Review P4/P5/P6 action list and side-effect classification before authorizing control development; any later physical execution needs separate target-specific authority | Approval of this planning document alone never runs an action or authorizes all device changes |

中文审核要点：固定参考版本；确认“API 一致”是跨语言一对一语义映射还是 Go 源码/ABI
兼容；逐项决定安全行为冲突，不能用保留差异冒充零差异；明确平台与硬件验收边界；
控制开发及实机操作分开授权。用户已要求继续无歧义的只读差分和修复；受未决契约影响的实现保持开放。

## 6. Staged delivery / 分阶段交付

| Phase | Scope and deliverable / 范围与交付 | Entry / 进入条件 | Exit / 验收门槛 |
| --- | --- | --- | --- |
| P0 — contract / 契约 | Approve decisions, translate every API shape, classify side effects and attach B cases to affected item IDs; freeze matrix and initial fixture plan | Review this draft | No implicit exclusions; unresolved safety/API decisions block affected work |
| P1 — foundations / 基础语义 | Transport, HTTP surface, auth/context/config, errors, JSON rules, entity/query/collection/cache helpers and public support APIs | P0 accepted | A-API/A-DATA/A-CALL/A-ERROR plus B01–B13/B18 for foundation items; actual GoFish differential evidence |
| P2 — complete current families / 补全已有模型 | All fields, enums, nested models, decoding/encoding and read links for currently overlapping families; preserve legacy/modern distinctions | P1 interfaces stable | Every P2 data/read row has a mapping and test; no subset-only projection called full parity |
| P3 — remaining reads/models / 其余模型与读取 | All remaining standard and Swordfish schemas, registries, metrics, storage, facilities, telemetry/event/task/job data and read/download APIs | P1/P2 contracts stable | Every remaining standard data/read item accounted for; no raw-JSON substitute for a missing typed contract |
| P4 — mutation foundation/common controls / 写入基础与常用控制 | Raw writes, payload/diff/ETag/apply-time semantics, async task handling, selected reset/boot/indicator/media/settings operations | Explicit control-development approval after P0; P1 error/transport gates complete | A-MUTATE/A-TASK in isolated synthetic services, permission-denial cases and ambiguous outcomes; no live actions |
| P5 — remaining stateful operations / 其余有状态操作 | All remaining standard actions: firmware, accounts/certificates/keys/license/security, diagnostics/clearing, automation/composition, storage replication/erase/reconfiguration | Explicit reviewed action list; P4 foundations | Every relevant action row closed against reference in mocks, including destructive/async/failure paths; no silent replay assumptions |
| P6 — OEM / 厂商扩展 | All five OEM packages, helper aliases and vendor-specific read/write/retry/reset semantics | Shared foundations ready; separate approval for OEM control development | Per-package public surface and all vendor-specific behavioral cases; mock evidence distinct from vendor hardware evidence |
| P7 — acceptance / 总体验收 | Full matrix reconciliation, backward-compatibility/API migration, approved platform matrix, independently authorized hardware profiles, final bilingual documentation | Prior phases and required environment access | No U/P or unresolved behavioral differences in the claimed scope; evidence for exact commits; no registry publication |

These are dependency-ordered milestones, not fixed calendar estimates. Split implementation
into reviewable batches by resource family; do not generate the entire schema framework
before validating the foundation and one complete representative family. Each batch closes
its own rows and regressions once; do not rerun unrelated exhaustive suites without cause.

按依赖推进，不在尚未确定契约和硬件前承诺工期。按资源族形成可审阅小批次，先验证基础和
一个完整代表模型，再考虑是否需要生成工具；不预建庞大框架。每批验证相关差距与回归，
没有新风险时不反复扩大测试。

## 7. Per-item acceptance contract / 逐项验收契约

Each item inherits its `acceptance` templates from the JSON matrix. Before it can become
`V`, record the MoonBit symbol, exact fixture/version, expected observable behavior,
reference and subject commits, actual command/CI URL, result and any linked B cases.
Store failures and unknowns as open cases. Changes to a shared decoder/traversal primitive
must test the impacted item families; a shared unit test is not automatically all-field proof.

逐项补齐 MoonBit 对应符号、夹具/版本、可观察预期、两端提交、实际命令/CI、结果及关联
B 项后才可转为 V。失败和未知不能跳过；公共解码/遍历改动须确认受影响模型范围。

| Template | Required cases / 必测内容 | Evidence / 证据 |
| --- | --- | --- |
| A-API | All public names/aliases/types/fields/enums/interfaces; parameter/default/return/error/embedding translation and caller lifecycle | Compile representative callers and check exhaustive symbol mapping; Go-only dependencies explicitly mapped |
| A-DATA | Every property/constant: defined, omitted, null, zero/false/empty, unknown enum/extra fields, wrong type, integer/float bounds, nested collections; decode and encode/update omission rules | Same bytes through both decoders; per-field assertion, not only a normalized inventory summary |
| A-EMBED | Promoted fields/methods through every embedding edge, collisions/shadowing, client/ETag/raw-data inheritance | Trace declaring type and effective public access; test representative embedding behavior plus complete mapping |
| A-CALL | URI/link discovery, method, query, meaningful headers/payload, response status/body, ordering/count, duplicate/inline/paged behavior, default config | Fresh fixture per client and captured request transcript; normalization allowed only by D-API |
| A-ERROR | Nil/missing/invalid inputs, 401/403/404/409/412/429/5xx, timeout/cancel/disconnect, invalid JSON, partial results and cleanup | Exact translated error/result/state contract, including failure timing and retained session/cache state |
| A-MUTATE | Add to every stateful callable after side-effect review: write permissions, action parameters/allowable values, ETag/apply time, expected and unexpected side effects, accepted-but-connection-lost, cleanup/retry | Stateful synthetic service with action ledger; no accidental duplicate operation; use pinned reference behavior and record conflicts |
| A-TASK | Add to async task/job APIs: synchronous vs 202, Location/Retry-After, absent body, progress/final state, cancellation, monitor failure, final headers/resource | Scripted time and mock task transitions; acceptance is never treated as completion |
| A-ENV | Every approved OS/architecture/toolchain and hardware/firmware/role profile; unsupported/missing resources included | Exact environment metadata and CI/authorized lab evidence; inaccessible hardware remains pending |

A-MUTATE/A-TASK/A-ENV are **additional** gates determined by actual implementation, not
optional tests omitted because a static symbol row lists only A-CALL. Any callable without
completed effect classification cannot enter a read-only implementation batch. Existing
31 unit tests, 30-file extended DMTF test and GoFish subset comparisons remain useful
regressions, but are insufficient to close the new matrix.

静态模板并不豁免写入、异步或环境测试；副作用未分类的方法不得混入只读批次。
既有 31 项单测、30 文件扩展样例及 GoFish 子集对照保留为回归证据，不能关闭全量矩阵。

## 8. Platform, hardware and permissions / 平台、硬件与权限

| Profile / 环境 | Current evidence / 当前证据 | Required before a claim / 声明前要求 |
| --- | --- | --- |
| Linux x86_64 (Ubuntu 24.04) | Existing native and selected GoFish CI passed | Full approved contract matrix on exact toolchain/dependencies |
| macOS arm64 (macOS 15) | Native CI and local selected GoFish comparisons passed | Same full matrix, including GoFish comparison in CI or retained equivalent evidence |
| Linux arm64, macOS x86_64, Windows x86_64 | No parity evidence; native dependency feasibility not yet established | Build/runtime feasibility and full differential suite; do not inherit results from another architecture |
| Other Go OS/architecture combinations | No agreed list or evidence | Explicitly resolve target set; unbounded “all platforms” is not supported by present evidence |
| DMTF/synthetic loopback services | Current selected read/session cases only | Full schema/property and scripted protocol/action cases; no real-device claim |
| Standard Redfish physical equipment | No physical BMC validated | Exact vendor/model/firmware/RedfishVersion; anonymous, read-only and separately authorized control roles |
| Swordfish/storage/fabric/PDU/cooling equipment | No hardware validated | Exact service/schema/firmware and feature availability; server BMC tests cannot substitute for these resource families |
| AMI, Dell, HPE, Supermicro, ZT OEM | No vendor hardware validated | Model/firmware/OEM version and per-action role/permission evidence; fixtures alone do not certify compatibility |

No fixed account name is a portable permission guarantee. Record advertised privilege maps,
actual role and observed 401/403 behavior; `Updateable` and similar capability flags are not
authorization. Store only synthetic/redacted fixtures in the repository; any authorized
hardware evidence must avoid credentials, private hostnames and device identifiers.

账户名称不等同于权限保证；记录权限映射、实际角色及拒绝行为，能力标志不作为操作授权。
仓库只保留合成或脱敏夹具。当前没有设备访问授权，硬件列是待验证要求，不是操作清单。

## 9. Completion rule and immediate next step / 完成标准与下一步

“Complete parity” requires zero missing mapped capabilities and zero unresolved observable
behavior differences **within the explicitly approved version/API/environment contract**.
An approved exception may define a useful compatibility subset, but it must not be described
as satisfying the original no-differences goal. Finite testing also cannot prove equality
for every possible server/input; report the exact tested contract and remaining uncertainty.

只有明确批准的版本、API 和环境契约内不存在缺失映射或未解决行为差异，才可声称该范围
完成对齐。若用户接受例外，可以形成有用的兼容子集，但不能说原“零差异”目标已实现。
有限测试不能证明所有可能输入/设备行为相同，交付始终写清实际证据边界。

Continue bounded read-only evidence and unambiguous defect fixes under the user's later
instruction. [Batch 01](gofish/READONLY-01.md) links measured cases to individual rows and
lists concrete D-PRESENCE, D-NUM, D-COLLECTION, D-JSON and D-AUTH recommendations.
[Batch 02](gofish/READONLY-02.md) implements independent DHCP/DNS/SLAAC fields and records
concrete nested-default, null DNS entry and source-comment/runtime conflicts.
Affected API/safety migrations remain pending; no control phase or physical test is authorized.

按用户后续指令持续推进只读差分及明确缺陷修复。证据 01 已关联具体条目并列明五项
具体决策及建议；不因测试通过而提升完整一致性状态，未决 API/安全迁移不擅自执行。

## Reproducing the inventory / 复核盘点

```sh
cd tools/gofish
go mod verify
go list -m -f '{{.Dir}}' github.com/stmcginnis/gofish
cd ../..
# Supply the module directory printed above; parses local source only.
go run tools/gofish_inventory.go /path/to/gofish@v0.27.0 > /tmp/gofish-source-index.json
```

Inventory validation on 2026-11-11: `go mod verify` passed; Go's package loader listed
exactly the same seven packages and 253 source files; a fresh AST run reproduced every
recorded source hash/declaration; all 11,580 row IDs are unique and the summary counts and
local links agree. This validation checks the audit artifact, not full GoFish behavior.
No additional hardware or control tests were run.

2026-11-11 已核对模块完整性、Go 包加载器的 7 包/253 文件列表、重新扫描后的全部源码
哈希/声明、11,580 个唯一条目标识、汇总计数及本地链接。这验证的是盘点制品，不是完整
行为一致性；没有额外进行硬件或控制测试。

The scanner emits original source fields. The checked-in matrix adds review states,
phase allocations and mapping candidates; those are assessments, not generated proof.
Compare `path/package/sha256/schema/release` and each symbol's `kind/name/signature/line`
with the scanner output. A new source symbol or changed hash cannot silently disappear.
No request to a BMC, upstream source execution, schema generation or publication occurs.

扫描器仅输出源码事实；矩阵增加的状态、阶段和候选映射是审阅记录，不是自动生成的正确性
证明。按上述字段核对即可发现增删和源码变化。复核不会访问设备、执行上游代码或发布。

[tag]: https://github.com/stmcginnis/gofish/tree/4cc897fb5c172996e8f34a31a5d1012b45a287a7
[subject]: https://github.com/pangbit/moonredfish/commit/b10066cb3d382f74489bce18513be1d0fe284ed7
[protocol]: https://www.dmtf.org/sites/default/files/standards/documents/DSP0266_1.23.0.pdf
[client]: https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/client.go
[collections]: https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/collection.go
[models]: https://github.com/stmcginnis/gofish/tree/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas
[sessions]: https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/session.go
[errors]: https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/types.go
[entity]: https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/entity.go
[tasks]: https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/task_monitor.go
[dell]: https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/oem/dell/idrac_monitor.go
