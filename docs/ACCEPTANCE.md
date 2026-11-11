# Reproducible acceptance / 可复现验收

This is an engineering review of the documented inventory subset, not a Redfish
certification, vendor compatibility claim, or an organizer's acceptance decision.
以下是已声明清单子集的工程验收，不代表 Redfish 认证、厂商兼容或赛事主办方的审核结论。

## One local review / 一次本地验证

Use the toolchain and native dependencies documented in the README. Python 3 and
OpenSSL are required for synthetic TLS tests. No BMC account or network access to a
device is required. Registry downloads are needed on the first build.
使用 README 所列工具链与 native 依赖；合成 TLS 测试需要 Python 3 和 OpenSSL。
不需要 BMC 账户或设备访问权限，首次构建需要从 registry 下载依赖。

```sh
moon update
moon check --target native --deny-warn
moon test --target native --deny-warn
moon build --target native --release --deny-warn
moon run examples/offline --target native
python3 tools/test_mock.py
moon info --target native
moon fmt --check
moon package --list
```

The offline output is `demo: Synthetic server (power: On)`. The mock runner reports
HTTP/session/pagination/limits/TLS success, then authenticated-example cleanup and
redaction success. It fails with a nonzero exit code if an assertion fails. Certificates
and keys exist only in an automatically cleaned temporary directory.
离线输出为 `demo: Synthetic server (power: On)`。mock 脚本先报告协议检查成功，再报告
认证示例的退出及脱敏检查成功；任一断言失败都会返回非零退出码。测试证书和密钥仅存在于
自动清理的临时目录。

## Three end-to-end use scenarios / 三个端到端使用场景

These are reproducible library/application workflows, not three claims of protocol
coverage. Run commands from the repository root with the README's native toolchain
and dependencies installed. Use the current checkout: the scoped-session and aggregate
budget behavior below is Unreleased, not part of the published 0.1.0 baseline. No real
credentials or device address is needed. Scenarios 2 and 3 share one runner; run it once.

以下是可复现的库/应用流程，不把三个场景等同于协议全覆盖。安装 README 所列 native
工具链和依赖后，在仓库根目录运行。使用当前源码：下文的作用域会话和累计预算行为属于
Unreleased，而非已发布的 0.1.0。不需要真实凭据或设备地址；场景 2、3 共用同一脚本，
只需运行一次。

### 1. Build a read-only asset inventory / 只读资产盘点

**Goal:** discover a service and enumerate systems, chassis and management controllers,
retaining resource IDs and types for an inventory application. The independent DMTF
public rack-mount sample supplies the inputs. This check requires access to GitHub to
fetch seven hash-pinned files, then uses loopback HTTP only.

**目标：**发现服务并枚举系统、机箱和管理控制器，为资产应用保留资源标识与类型。
输入使用独立的 DMTF 公开机架服务器样例；需要访问 GitHub 下载 7 个固定哈希文件，
随后仅使用本机回环 HTTP。

```sh
python3 tools/test_reference.py
```

**Expected:** exit 0 and `pinned DMTF mockups: root and three inventory collections passed`,
followed by the pinned source commit and `7 hashes verified`. The executable asserts one
system (`437XR1138R2`), one chassis (`1U`) and one manager (`BMC`), with resource types
present. The runner verifies that all seven routes were read and no unexpected or
mutating request occurred. Missing or changed upstream data fails rather than falling
back to a synthetic success. See [the executable](../examples/reference/main.mbt) and
[provenance and limitations](REFERENCE.md). This is resource-shape evidence, not physical
hardware or authentication evidence.

**预期：**退出码为 0，输出上述成功行及固定源提交和 `7 hashes verified`。程序断言系统
`437XR1138R2`、机箱 `1U`、管理控制器 `BMC` 各一个且均有资源类型；脚本确认访问了
全部 7 个路由，没有意外请求或写请求。上游数据缺失或变更会失败，不会替换为自造成功
数据。此处证明资源格式与遍历，不证明物理设备或认证兼容。

### 2. Read a paged inventory without duplicate assets / 分页盘点并避免重复资产

**Goal:** a collector follows next-page links and obtains each unique resource once,
while rejecting cycles and stopping at explicit resource/time budgets instead of
returning a misleading partial inventory. The existing synthetic service has two Systems
pages: member 1 on the first page, members 1 and 2 on the second.

**目标：**采集器跟随下一页链接，每个唯一资源只返回一次；遇到循环或超出资源/时间预算
时明确失败，而不是返回容易被误认成完整清单的部分结果。现有合成服务的 Systems 第一页
包含成员 1，第二页包含成员 1 和 2。

```sh
python3 tools/test_mock.py
```

**Expected:** exit 0 and `mock integration: HTTP, session, pagination, limits, and TLS passed`.
The [integration executable](../examples/integration/main.mbt) asserts exactly two systems
with IDs `1` and `2`, rather than three entries. It also asserts `PaginationCycle`,
`PageLimit`, `MemberLimit`, `TotalResponseTooLarge` and `OperationTimeout` on the corresponding
fixtures. These assertions run automatically; no server needs to be started separately.
The runner requires Python 3 and OpenSSL and creates temporary local HTTP/HTTPS services.
Pagination is not a transactional snapshot: service-side changes can still cause omissions.

**预期：**退出码为 0，输出上述集成成功行。集成程序断言仅返回标识为 `1`、`2` 的两个
系统，而非三条记录；对应异常样例分别断言分页循环、页数、成员数、累计正文大小和操作
超时错误。无需另起服务器，脚本自动运行断言并创建临时 HTTP/HTTPS 服务；需要 Python 3
和 OpenSSL。分页不是事务快照，服务端并发变化仍可能造成遗漏。

### 3. Collect authenticated counts and close the session / 认证采集数量并关闭会话

**Goal:** a scheduled inventory application authenticates over verified HTTPS, reports
only aggregate counts, and attempts logout even when a read fails. Run the same
`python3 tools/test_mock.py` command once for both this scenario and scenario 2. It launches
the actual [session inventory example](../examples/session_inventory/main.mbt) with
synthetic environment credentials and a temporary trusted CA, first successfully and
then with an injected Systems HTTP 403 response.

**目标：**定时采集应用通过验证证书的 HTTPS 认证，只报告汇总数量，并在读取失败时也
尝试退出。与场景 2 共用上述脚本，一次运行即可。脚本以合成环境凭据和临时可信 CA 启动
实际认证清单示例，先验证成功路径，再注入 Systems HTTP 403 验证失败路径。

**Expected:** the runner finishes with `mock server: authenticated example, success/error cleanup, redaction and expected paths verified`.
It captures (rather than printing) the successful application's
`inventory: systems=2, chassis=1, managers=1`, then verifies a nonzero application exit
and HTTP 403 diagnostic on failure. It checks balanced login/logout counts across its
lifecycle cases and rejects output containing the synthetic password, token or private
response body. A passed runner exits 0 even though the deliberately failing child exits
nonzero. Temporary certificates and servers are cleaned up automatically.

**预期：**脚本最终输出上述认证示例成功行。成功应用的数量输出被脚本捕获而非直接打印；
失败应用须返回非零退出码且包含 HTTP 403 诊断。脚本检查其生命周期用例登录/退出数量
相等，并检查输出不含合成密码、令牌或私密响应正文。预期失败的子进程返回非零不影响
通过全部断言的脚本返回 0；临时证书和服务器会自动清理。

Session creation/deletion changes remote session state, though no device setting changes.
Cleanup has a deadline and can itself fail; this is not an unconditional guarantee that
an arbitrary BMC session is deleted. For authorized real use, the README documents the
HTTPS example and caller-managed credentials. Do not disable TLS verification, commit
credentials, or infer physical-device interoperability from these local fixtures.

创建/删除会话会改变远端会话状态，但不改变设备配置。清理有时限且本身可能失败，不能
保证任意 BMC 会话都一定删除。授权实机使用方式和调用方凭据管理见 README；不得关闭
TLS 验证或提交凭据，也不能从本地样例推断真实设备互通已经通过。

## Evidence map / 证据对应

| Claim / 声明 | Check / 检查 |
| --- | --- |
| Optional fields and strict JSON / 可选字段与严格 JSON | Unit tests and compiled README example / 单测与 README 编译示例 |
| Systems, Chassis, Managers / 三类资产清单 | Synthetic collections and resource GETs / 合成集合与资源读取 |
| Safe pagination / 安全分页 | Next links, duplicate suppression, cycles, page limits, unsafe URI rejection / 下一页、去重、循环、上限与危险 URI 拒绝 |
| Verified HTTPS / HTTPS 验证 | Untrusted certificate rejection, custom CA success, hostname mismatch rejection / 不可信证书拒绝、自定义 CA 成功、主机名不匹配拒绝 |
| Error diagnostics / 错误诊断 | Default status preserved; opt-in codes and MessageId with bounded fields / 默认状态保留，可选且字段受限的代码与 MessageId |
| Authentication lifecycle / 认证生命周期 | Login errors, discovery, token use, scoped cancellation cleanup, logout retry/expiry and lifecycle overlap rejection / 登录错误、发现、令牌、取消清理、退出重试/过期及并发拒绝 |
| Bounded requests / 有限请求 | Per-request and operation deadlines, per-response and total body limits, unique-member cap, no redirects / 请求及操作总时限、单次及累计正文限制、唯一成员上限、不跟随重定向 |
| Output minimization / 输出最小化 | Example prints counts; tests exclude synthetic passwords, tokens and private response bodies / 示例仅打印数量，测试排除合成密码、令牌与私密响应正文 |

The GitHub Actions workflow repeats these checks on Linux x86_64 and macOS arm64.
Inspect the workflow result for the exact commit under review, not just the presence of
a workflow file. `moon package --list` is packaging, not registry publication.
GitHub Actions 在 Linux x86_64 与 macOS arm64 重复这些检查。请查看待审提交对应的实际结果，
不能只看工作流文件是否存在。`moon package --list` 仅打包，不发布到 registry。

## Independent sample check / 独立样例检查

```sh
python3 tools/test_reference.py
```

This optional local check downloads seven pinned DMTF public mockups, verifies SHA-256,
and serves them only on loopback. Linux CI covers the same fixtures through the comparison
below. See [REFERENCE.md](REFERENCE.md)
for provenance, copyright and the narrow interoperability claim.
本地可选步骤会下载 7 个固定的 DMTF 公开样例，校验 SHA-256，仅在回环服务上使用。
Linux CI 通过下方对照覆盖同一批样例；来源、版权与有限互通结论见上述说明。

## GoFish comparison / GoFish 对照

With Go 1.21+ installed, run `python3 tools/test_gofish.py`. Linux CI also runs it.
This checks the common read-only subset, not full feature parity. The runner verifies
each client's selected output against pinned inputs and explicit synthetic expectations;
it does not treat either client as the sole oracle. See [COMPARISON.md](COMPARISON.md).

安装 Go 1.21+ 后运行上述命令；Linux CI 也会执行。仅验证共同的只读子集，不追求全量
功能对等。两个客户端的选定输出分别对照固定输入与明确的合成预期，不以任一客户端
作为唯一正确性标准，详细边界见对照说明。

## Boundaries / 边界

- No real BMC was used. Device interoperability requires a separately authorized test.
  未使用真实 BMC；设备互通需要另行授权验证。
- There are no device-mutating APIs. Session creation/deletion still changes remote state.
  不提供设备写操作 API，但创建/删除会话仍会改变远端状态。
- This is not GoFish/Swordfish feature parity, exhaustive schema coverage, or a performance benchmark.
  不代表 GoFish/Swordfish 功能对等、全 schema 覆盖或性能基准结论。
- Keep registration identity and private operational evidence out of the repository.
  报名身份信息和私密运维证据不得提交到仓库。
- Published 0.1.0 and source changes under Unreleased are distinct. Only the maintainer
  publishes subsequent versions manually.
  已发布的 0.1.0 与 Unreleased 源码改动须区分；后续版本仅由维护者手动发布。

## Typed hardware extension / 类型化硬件扩展

The Unreleased [inventory guide](INVENTORY.md) lists exact fields, units and modern
resource boundaries. Run `moon run examples/hardware --target native` offline. Native
unit tests and `tools/test_mock.py` cover Missing/Null/Value, wrong types, unknown status,
linked collections, errors and shared limits. `tools/test_gofish.py` additionally checks
18 pinned DMTF files and a minimal synthetic modern graph through both typed clients.

具体字段、单位和现代资源边界见上述指南。离线硬件示例、原生单测和本机集成覆盖三态值、
错误类型、未知状态、链接集合、错误及共享限制；GoFish 对照另覆盖 18 个固定 DMTF 文件
与最小现代资源合成图。未进行真实 BMC 验证，也未发布 Mooncakes。
