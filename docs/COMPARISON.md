# GoFish comparison / GoFish 对照

## Run and scope / 运行与范围

```sh
python3 tools/test_gofish.py
```

Requires the README's native toolchain, Python 3.9+, OpenSSL and Go 1.21+ (verified with
Go 1.24.0). First use downloads GoFish through Go modules and eighteen public DMTF JSON
files from GitHub. Linux CI runs this test; Go is not a library/runtime dependency.

需要 README 所列 native 工具链、Python 3.9+、OpenSSL 和 Go 1.21+（已验证 Go 1.24.0）。
首次运行通过 Go modules 下载 GoFish，并从 GitHub 下载 18 份公开 DMTF JSON。
Linux CI 执行该测试；MoonBit 库本身不依赖 Go。

- Reference client: [GoFish v0.27.0](https://github.com/stmcginnis/gofish/tree/v0.27.0),
  commit `4cc897fb5c172996e8f34a31a5d1012b45a287a7`, BSD-3-Clause. Version and module
  checksums are pinned in `tools/gofish/go.mod` and `go.sum`; no upstream code is vendored.
- Inputs: eighteen unchanged, SHA-256-pinned [DMTF mockups](REFERENCE.md), commit
  `23d21f9a3610f6b6fbb71ffc941296b159a524d2`, plus explicitly synthetic responses.
- Subject: this checkout, not automatically the published Mooncakes 0.1.0 package.
  Use the exact tested Git commit or CI run to identify the source under review.

对照版本和校验值已固定，不在仓库中分发上游代码。输入为固定的 DMTF 原始样例和明确标记
的合成响应。被测对象是当前 checkout，不是自动等同于 Mooncakes 已发布的 0.1.0；
查看实际测试提交或对应 CI 确认源码版本。

## Checked result / 验证结果

The first local run on 2026-11-10 passed for both clients on macOS arm64. Re-run the
command or inspect the exact commit's Linux CI for current evidence.
2026-11-10 首次 macOS arm64 本地对照中两端均通过。当前证据以重跑命令或具体提交的
Linux CI 为准，不将静态说明当作未来版本必然通过的承诺。

| Check / 检查 | Expectation / 预期 |
| --- | --- |
| Official inventory / 官方清单样例 | ServiceRoot and one System, Chassis and Manager; URI, Id, Name, type and PowerState agree with source data / 服务根及三类各一个资产，选定字段与原始输入一致 |
| Collections / 集合 | Two distinct Systems across two pages; empty Chassis; pagination loop reported as an error / 两页两个系统、空机箱集合、分页循环报错 |
| HTTP errors / HTTP 错误 | Wrong password 401, denied read 403, missing resource 404; bounded comparison of error code and MessageId / 错误密码 401、拒绝读取 403、资源缺失 404，并对照错误码及 MessageId |
| Invalid JSON / 无效 JSON | Typed read fails rather than returning a resource / 类型化读取失败，不伪造资源 |
| Session / 会话 | 201 login, token-authenticated reads, one successful DELETE and no remaining test session / 201 登录、token 认证读取、成功退出且不遗留测试会话 |
| TLS | Trusted temporary CA succeeds; untrusted CA fails before any HTTP request / 临时可信 CA 成功，不可信 CA 在 HTTP 请求前失败 |

Each client receives the same bytes and a fresh server instance. Arrays are compared by
URI, not incidental request order. The Python runner independently derives the selected
inventory expectation from the pinned input; synthetic expectations are explicit.
GoFish uses its typed resource APIs, with automatic `$expand` disabled. Both use a
10-second request deadline; this is not a speed or request-count benchmark.

两端使用相同字节和各自全新服务实例，数组按 URI 比较，不比较偶然请求顺序。清单预期
由 Python 从固定输入独立提取，合成预期明确写出。GoFish 使用类型化资源 API，不启用
自动 `$expand`。请求时限均为 10 秒，但这不是性能或请求数量基准。

## Typed hardware comparison / 类型化硬件对照

The hardware mode uses 18 hash-pinned DMTF files for System/Chassis/Manager asset and
health summaries, 3 Processors, 4 Memory modules, 3 temperatures, 2 fans, 1 power supply
and 1 power-control entry. A separate 13-route synthetic graph covers a modern Sensor,
ThermalSubsystem/Fan and PowerSubsystem/PowerSupply. See [INVENTORY.md](INVENTORY.md)
for exact public API scope. The synthetic graph is not a DMTF sample or real hardware.

硬件模式使用 18 个固定哈希的 DMTF 文件，对照资产/健康摘要和上述组件；独立 13 路由
合成图覆盖现代 Sensor、Fan 和 PowerSupply 链接路径。公开 API 范围见类型化指南，
合成图不冒称 DMTF 样例或真实硬件。

The runner checks exact collection sizes and resource URIs, then every selected defined,
non-null property against the original fixture. It also compares UUID, socket and
architecture when defined. GoFish scalar defaults cannot distinguish missing/null, so
extra absent-property defaults are ignored in this comparison only. MoonBit's three-state
contract is tested separately. A missing adapter field that exists in the fixture fails.
No sensor values or units are inferred from another field.

runner 检查精确数量和资源 URI，再把所有选定且非 null 的有值字段分别对照原输入，
包含存在时的 UUID、插槽和架构。GoFish 标量默认值不能区分缺失/null，因此仅此对照忽略
缺失属性多出的默认值。MoonBit 三态契约由独立测试验证；适配器遗漏样例已有字段会失败，
不从其他字段推导或伪造测量值、单位。

In GoFish v0.27.0, subsystem accessors return legacy fan/supply types. The test adapter
follows those links, then reads each URI using GoFish's modern `GetFan` or
`GetPowerSupplyUnit`, so SpeedPercent and modern assets are actually decoded by the
modern typed API. The extra GET is intentional, not a request-count comparison.
The bounded public graph exercises traditional Thermal/Power; only the separate modern
graph omits both legacy links and exercises subsystem paths. Production APIs do not
impose that either/or restriction.

固定 GoFish 版本的子系统访问器返回旧风扇/电源类型，测试适配器先跟随这些链接，再以
现代类型化 API 读取同一 URI，真正验证 SpeedPercent 和现代资产字段。额外 GET 是有意
的，不是请求数量竞赛。公开图验证传统路径，独立现代图省略两种旧链接后验证新路径；
生产 API 不要求新旧资源二选一。

## Extended inventory comparison / 扩展清单对照

```sh
python3 tools/test_extended.py
```

This command uses the same GoFish v0.27.0 and DMTF commit, with 23 additional
hash-pinned files plus the seven discovery files (30 total). It compares selected
defined fields for Ethernet interfaces, logs, firmware and current BIOS attributes.
A separate 26-route synthetic graph covers all nine new resource families, including
Storage/Drives/Volumes, NetworkAdapters, false/zero values and paginated log entries.
Exact resource counts, URIs, defined-field values and advertised route coverage are
checked for both clients. See [INVENTORY.md](INVENTORY.md#extended-read-only-inventory-unreleased--扩展只读清单未发布)
for the public API and model limits.

该命令使用相同的 GoFish v0.27.0 和 DMTF 提交，新增 23 个固定哈希文件，连同 7 个基础
发现文件共 30 个，对照网络接口、日志、固件及当前 BIOS 属性的选定有值字段。独立的
26 路由合成图覆盖九类新增资源，包括存储/磁盘/卷、物理网卡、false/零值及日志分页。
两端均检查精确资源数量、URI、有值字段及显式链接路由覆盖；API 和模型边界见类型化指南。

The DMTF log collections embed full entries. GoFish can decode those entries without
member GETs; the comparison adapter deliberately reads each advertised entry URI with
`schemas.GetLogEntry` so both clients decode the same standalone resource bytes.
This extra read is test-only and is not evidence of identical request counts. The
public log sample is not pagination evidence; pagination uses the separate synthetic
`Members@odata.nextLink` graph. The unreferenced upstream AC-RoT0 sample is excluded.
Missing/null semantics and traversal limits remain moonredfish-specific regression
checks, not GoFish equivalence claims. No physical BMC has been tested.

DMTF 日志集合内嵌完整条目，GoFish 可以直接解析而不发成员 GET；对照适配器有意使用
`schemas.GetLogEntry` 读取已发现的条目 URI，使两端解码相同独立资源字节。额外读取仅用于
测试，不说明请求次数相同。公开日志样例不作为分页证据，分页使用独立合成图中的
`Members@odata.nextLink`。未被集合引用的 AC-RoT0 不纳入夹具。缺失/null 及遍历预算由
moonredfish 自身回归验证，不宣称与 GoFish 等价。尚未进行真实 BMC 测试。

## Detailed differential evidence / 细粒度差分证据

Run `python3 tools/test_parity.py` for 39 bounded synthetic cases covering numeric
spelling/ranges, missing/null/defaults, JSON decoding and collection order/duplicates/
embedded/partial results. [Batch 01](gofish/READONLY-01.md) records 7 matching selected
observations, 10 both-reject cases and 22 open differences. The adapters preserve Field
states and partial results. Linux CI runs this batch; current committed evidence is local
macOS arm64. Neither result closes full API/model acceptance.

运行上述命令可复核 39 个细粒度合成场景，保留缺失/null/默认值、数组顺序、重复、部分结果
和请求记录。证据 01 中 7 个选定观测相同、10 个两端拒绝、22 个差异；矩阵保持未完成。

## Network configuration implementation / 网络配置实现

`python3 tools/test_network_config.py` exercises the added DHCPv4/DHCPv6/SLAAC,
DNS and interface policy read APIs, including explicit owner-link traversal. It checks
all supplied fields, nested presence, wrong types, enum strings and DNS member behavior.
[Batch 02](gofish/READONLY-02.md) contains exact inputs, observations, remaining differences
and recommendations. These functional reads extend the library; they do not close full
EthernetInterface or API-shape equivalence.

该命令验证新增网络配置读取，包括真实 owner→集合→接口调用路径及新增字段值。
证据 02 给出明确输入、两端表现、影响和建议；不会把候选映射或测试数量当成完整一致。

## PCIe implementation / PCIe 实现

`python3 tools/test_pcie.py` exercises typed device/function/interface reads and five
explicit topology APIs. It verifies collection/legacy priorities, source order, pagination,
prevalidation and partial-failure differences, plus GoFish's vendor lane conversions.
See [batch 03](gofish/READONLY-03.md) and the [consolidated decision review](gofish/DECISIONS.md).
PCIe 模型与导航的实际对照保留默认值、严格解码、重复和部分结果差异，不以用例数表示完整一致。

## Open differences / 待解决差异

GoFish is the pinned behavior reference for the full-parity goal; DMTF remains the protocol specification. Its error strings can
retain raw response bodies, so the adapter extracts selected error fields without
printing the original error or enabling HTTP dumps. `Logout()` returns no error;
the server separately verifies deletion. Its collections may return partial data with
an error, while moonredfish rejects incomplete inventory. Missing collection links,
absent/null/zero values, duplicate members, redirects and resource limits need their own
contract review; this small comparison does not assert equivalence for those cases.

GoFish 是完整对齐目标的固定行为参照，DMTF 是协议规范。其错误字符串可能保留原始响应，因此适配器只提取选定字段，不输出
原始错误或 HTTP dump。`Logout()` 没有错误返回，故由服务端另行核实删除。它允许集合
返回部分数据加错误，moonredfish 则不返回不完整清单。缺失集合链接、缺省/null/零值、
重复成员、重定向及资源上限需要按各自契约审阅，本对照不宣称这些行为相同。

The DMTF Mockup Server's session implementation returns 204 with a fixed test token;
it is not used as the login oracle. This test serves official **data** through a minimal
local fixture, not the official server executable. Session checks use a separate synthetic
HTTPS endpoint with 201 and a valid Location/token. We do not relax moonredfish's login
checks to accommodate the mock server. This is not full Redfish conformance, complete
GoFish/Swordfish/OEM parity, cancellation/logout-failure equivalence or real-BMC compatibility.

DMTF Mockup Server 的会话实现返回 204 和固定测试 token，因此不作为登录正确性的依据。
此测试使用官方**数据**，服务端是最小回环 fixture，不是官方模拟器程序本体。会话使用
独立合成 HTTPS 服务，返回 201 及有效 Location/token；不为适配模拟器放宽登录检查。
不代表完整 Redfish 符合性、GoFish/Swordfish/OEM 全量对等、取消/退出失败语义相同，
也不代表真实 BMC 兼容。

## Boot and Secure Boot comparison / 启动配置与安全启动对照

`python3 tools/test_boot.py` checks 35 synthetic cases for five selected read views,
four navigations and both GoFish BootOptions entry points. It asserts source order,
pagination, missing/null/defaults, current versus next flags, inline data, errors and
requests. Two targeted issue cases preserve raw property annotations and distinguish
current Boot from Settings without reading/writing Settings. See [batch 04](gofish/READONLY-04.md)
for exact results and [upstream issue review](gofish/ISSUES.md) for pinned-version findings.

该命令验证五类选定视图、四条导航、两条参考 BootOptions 入口及请求轨迹。35 场景中
14 个选定观测相同，4 个两端拒绝但错误不同，17 个有差异；不把原始数据保留或普通分页
通过当作类型化注解、自动 expand 或全量 GoFish 一致。兼容模式建议仍待用户决定。

## Task comparison / 任务对照

`python3 tools/test_task.py` checks 35 synthetic cases for TaskService, Task and nested
Message reads plus explicit service/tasks/subtasks/created-resource navigation. It verifies
pagination/result order and GET multiplicities, including no implicit monitor, action,
payload or recursive child requests. Nine selected observations agree, four both reject
with different categories and 22 remain different; see [batch 05](gofish/READONLY-05.md).

35 场景对照任务状态/进度/消息、三态、数值边界、整对象解码、内嵌选择、重复和部分结果。
不把普通 JSON 保留、部分相同或测试数量当作完整一致。用户确认的
[两份 DMTF 参照例外门槛](gofish/EXCEPTIONS.md)已记录；现已补充下述八个通用入口同输入运行；类型化字段校验未覆盖，也未宣布缺陷例外。

## Certificate comparison / 证书对照

`python3 tools/test_certificate.py` checks 30 synthetic cases across certificate/identity
fields and six navigation APIs. Eleven selected observations agree, three both reject with
different error categories and sixteen differ. See [batch 06](gofish/READONLY-06.md).
证书对照包含三态、未知值、身份数组、分页、系统/Boot 来源区分、内嵌、重复及部分结果；
读取证书字符串不证明其密码学或信任有效性。

## Virtual-media reads / 虚拟介质读取

`python3 tools/test_virtual_media.py` runs 30 synthetic cases: twelve selected observations
agree, five both reject and thirteen differ. It compares reported states, pointer versus scalar
booleans, derived action-advertisement flags, System/Manager pagination and separate server/client
certificate sources. Request traces reject image/action/ActionInfo access and check duplicate,
partial-error and path behavior. See [batch 07](gofish/READONLY-07.md).

30 个场景保留默认值、null、整对象/局部解码及集合差异；不把声明的动作当成执行能力，也不
把服务端 VerifyCertificate 报告值应用于本地 TLS。官方数值差异仍沿用上一批未决结论。

## Action metadata / 动作元数据

`python3 tools/test_action_info.py` compares 32 metadata/query/annotation cases against
GoFish: thirteen selected observations agree (including a common HTTP error), seven both
reject with different categories and twelve differ. Parameter selection checks first-match
order, type filtering, wildcard types, missing/null values and case sensitivity. Annotation
reads compare System/Manager reset and VirtualMedia insert getters without executing actions.
See [batch 08](gofish/READONLY-08.md). A separate opt-in [routing review](gofish/ACTION-INFO-ROUTING-01.md)
executes two GoFish EjectMediaActionInfo cases and audits the pinned official source coverage;
it does not pretend those source audits are official runtime comparisons.

32 个场景涵盖参数元数据、查询和注解读取；两个弹出链接复现另行登记。官方审阅未建立
可比较的选择器契约，例外门槛仍未满足；不重复运行已有数值探针，不执行任何动作。

## Official numeric reference checks / 官方数值参照核验

`tools/test_official_numbers.py` is an opt-in harness requiring the exact clean DMTF
reference checkouts and a built libredfish. Eight identical byte inputs were executed on
macOS arm64 through Redfishtool raw GET, real libredfish payload/accessors and the existing
typed adapters. See [commands, observations and limits](gofish/OFFICIAL-NUMBERS-01.md).
The official generic paths retain original type/value, but typed PCIe/Task validation and
coercion equivalence are unestablished. This is not part of normal Linux CI and declares
zero verified exceptions.

官方同输入核验已实际完成八个探针；通用读取与 getter 的结果逐项记录，不将其冒充同形
字段校验或已核实例外。外部源码和构建仅作为按需测试依赖，不进入库运行时。

## Safety / 安全

Adapters accept only numeric loopback endpoints. The runner permits only reads plus
creation/deletion of its own synthetic session. It checks requested routes, session
counters and output minimization. No real credentials, devices or raw device captures
are used. Temporary certificates, keys and the Go executable are cleaned up; public
mockups remain in memory with their copyright fields intact. No registry publication
or registration action is part of this command.

适配器仅接受数值回环地址。runner 只允许读取和创建/删除自己的合成会话，并检查请求路径、
会话计数与输出最小化。不使用真实账号、设备或设备抓包。临时证书、密钥与 Go 可执行文件
自动清理，公开 mockup 仅在内存保留原始版权字段。本命令不包含发布或报名动作。
