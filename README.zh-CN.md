# moonredfish

[English](README.mbt.md)

**版本状态：** Mooncakes 当前版本仍为 0.1.0。本文也介绍仅存在于 GitHub 当前源码的
Unreleased 新 API 与示例；安装 0.1.0 不会获得这些新增内容，具体见
[CHANGELOG.md](CHANGELOG.md)。后续 registry 版本仅由维护者手动发布。

面向 **MoonBit native** 应用的小型 Redfish 资产清单客户端。个人维护，Apache-2.0
许可；不是 DMTF 认证产品，也不是 GoFish 的移植版。

## 已实现范围

- 使用系统根证书或调用方指定的 CA 文件验证 HTTPS。
- ServiceRoot 发现、Systems / Chassis / Managers，以及任意资源的只读 GET。
- 会话创建与删除；令牌仅保存在不透明客户端对象中，不主动打印。
- 集合分页、链接去重、循环检测与页数上限。
- 单次请求超时和响应正文大小限制；不跟随重定向，不自动重试。
- 保留原始 JSON，支持访问可选属性与 OEM 字段，不建立庞大的生成式 schema 框架。

**边界：仅清单读取与认证生命周期。** 不提供电源重启、固件更新、账户修改、PATCH，
也不提供任意 POST / DELETE。不支持 Swordfish、事件订阅、任务轮询、Basic 认证，
不承诺任何厂商的完整兼容。当前验证仅使用本地合成 HTTP / HTTPS 服务，未连接真实 BMC。
会话创建会改变服务端状态，不能视为纯粹的只读操作。

## 安装与示例

需要 native MoonBit 工具链与 `moonbitlang/async` 0.22.1。已验证编译器为
`v0.10.20+65efd5b93`，`moon` 为 0.1.20261104。网络和 TLS 直接复用官方 async 库。
Linux CI 需要 OpenSSL 与 zlib 开发包，平台依赖见
[async 项目](https://github.com/moonbitlang/async)。

在源码目录运行完全离线的示例：

```sh
moon run examples/offline --target native
```

使用 `moon add pangbit/moonredfish@0.1.0` 安装 0.1.0，在调用方的 `moon.pkg` 中
导入 `pangbit/moonredfish`。
英文文档包含编译检查过的最小解析示例。

native 异步应用创建 `Client::new("https://bmc.example.invalid")`，再调用
`service_root()`、`systems()`、`chassis()`、`managers()`、`get(path)` 或
`members(path)`。包含 `async fn main` 的包还需导入 `moonbitlang/async`。
`members` 只返回成员 URI，清单方法会继续逐一获取资源。

```sh
# 仅在已获得目标设备访问授权时使用。此示例为匿名 HTTPS 请求。
moon run examples/inventory --target native -- https://authorized-bmc.example.invalid
```

认证应用可以使用 `with_session(username, password, body)`：正常返回、异常或取消时
都会尝试退出，完成清理后才返回 body 结果。清理屏蔽异步取消，但仍受 `timeout_ms`
限制。body 与清理同时失败时，清理错误优先；退出失败会保留本地会话，供调用方明确重试。
不要在 body 中修改会话，也不要并发共享该客户端。重叠的登录/退出调用会返回
`SessionBusy`，避免重复发起生命周期请求。

需要手动控制时，由应用提供凭据调用 `login(username, password)`，读取后调用
`logout()`，并自行处理异常与取消清理。库不后台重新登录，
基础登录/退出方法也不会自动退出会话。登录从 ServiceRoot 的 `Links.Sessions` 发现集合，
不必访问 SessionService；缺少该链接或根访问返回 401/403 时才使用标准路径
`/redfish/v1/SessionService/Sessions`。不安全或格式错误的已声明链接会被拒绝，不会
静默替换。登录响应的 Location 必须是所选集合的直接成员。发现路径还必须以 `/Sessions`
结尾（可有尾随 `/`），避免错误链接将登录或退出指向 Systems 等非会话集合。
这是刻意保留的兼容性限制，不常规的集合名称会被拒绝。同一客户端的登录/退出必须串行，且不可与该客户端其他请求重叠。
登录失败或取消时，远端可能已经创建会话，只是响应尚未返回。不要自动重试；应通过
已授权的管理工具检查会话状态。

当前源码还提供 `examples/session_inventory`（不包含在已发布的 0.1.0 示例集合中）。
该示例从应用环境读取 `REDFISH_USERNAME`、`REDFISH_PASSWORD` 和可选的
`REDFISH_CA_FILE`，通过 HTTPS 获取清单，只打印数量，并在成功、失败或取消时尝试退出
会话（通过 `with_session`）。清理请求仍受超时限制且可能失败；退出失败会令示例报错，不会宣称清理成功。
环境变量可避免把密码放在命令行参数中，但不是密钥保险库：应保护启动进程，且不要提交
`.env` 文件。

```sh
# 由可信启动器提供环境变量，不要在此处粘贴密码。
moon run examples/session_inventory --target native -- https://authorized-bmc.example.invalid
```

下方 mock 脚本会使用合成凭据和本地 TLS 服务运行这个真实示例入口，覆盖清单读取失败
后的退出路径。审阅认证流程不需要连接真实设备。

## 安全默认值与限制

- 构造客户端不会发起连接。默认只允许 HTTPS；只有显式设置
  `allow_loopback_http=true` 才能访问本机回环 HTTP mock。不提供跳过 TLS 验证的选项。
  `ca_file=...` 可指定由应用管理的 PEM CA 文件。
- 自动访问的链接必须为同源 `/redfish/v1` 相对路径。拒绝绝对 URL、编码的路径片段、
  路径穿越、片段标记、反斜杠和控制字符；查询串允许百分号编码。
  这是有意选择的严格子集，可能拒绝部分厂商返回的合法但不受支持的 URI。
- 默认单次请求 10 秒超时、正文最多 4 MiB、集合最多 100 页。每次请求后关闭连接，
  无连接池和缓存。`members`、`systems`、`chassis`、`managers` 还为整个操作共享
  60 秒截止时间（`operation_timeout_ms`）、10,000 个唯一成员上限（`max_members`）
  和 16 MiB 累计响应正文预算（`max_total_response_bytes`）。这是传输量限制，
  不是精确堆内存限制。超限分别返回 `OperationTimeout`、`MemberLimit` 或
  `TotalResponseTooLarge`，不返回部分结果。清单预算包含根发现、所有分页和成员 GET，
  每次调用独立计量。分页不是快照：服务端变化仍可能造成遗漏；nextLink 查询串保持不透明，
  去重不等于保证快照一致性。
- GET 非 2xx 状态返回 `HttpStatus(status)`，不会在错误中包含响应正文。
  显式设置 `detailed_errors=true` 可获得 `DetailedHttpStatus(info)`，包含状态码、
  标准 `error.code` 及最多 16 个去重的 ExtendedInfo `MessageId`。每个标识最多保留
  256 个 ASCII 标识字符，不保留自由文本消息、参数、解决建议、响应头或正文。
  标识仍来自服务端，不保证可安全公开。默认的 `HttpStatus` 行为不变；这不是完整的
  消息注册表解码器。JSON 必须是合法 UTF-8 且不可含重复键；网络与 TLS 错误保持
  官方 async 库的错误类型。
- 缺失属性保持缺失，不编造默认值。原始 `Resource.json` 可能包含私密资产信息，
  应用在记录或分享前必须脱敏。不要提交真实凭据、令牌、硬件标识、内网主机名或抓包。

## 验证

```sh
moon update
moon check --target native --deny-warn
moon test --target native --deny-warn
moon run examples/offline --target native
python3 tools/test_mock.py
moon info --target native
moon fmt --check
moon package --list
```

集成脚本需要 Python 3 和 OpenSSL，只在动态分配的回环端口启动合成服务，并临时生成
自签名证书。覆盖登录/退出、发现、分页去重、不安全链接及重定向拒绝、非法 JSON、
HTTP 错误、正文/页数/时间限制、不可信证书、主机名不匹配的拒绝与指定 CA 的 HTTPS 成功路径；同时检查认证示例的
成功/失败退出流程，并断言其输出不包含凭据、令牌或响应正文。
该脚本的所有凭据与设备信息均为合成数据。脚本不访问真实设备或外部测试服务。
请通过 Python 脚本运行，不要单独启动 `examples/integration`。

CI 配置面向 Linux x86_64 与 macOS arm64；配置文件存在不代表远端运行已通过。
真实设备互通、其他平台和 Redfish 完整符合性均需独立验证。

## 对照项目与设计取舍

- [DMTF Redfish](https://www.dmtf.org/standards/redfish)：协议参考。
- [GoFish](https://github.com/stmcginnis/gofish)，BSD-3-Clause：成熟 Go 客户端，覆盖
  Redfish / Swordfish、大量强类型资源和操作。moonredfish 对照其客户端、发现和清单
  使用方式，但未复制其源码，不继承其覆盖范围、品牌或兼容性承诺，也不兼容其 API。
- [moonbitlang/async](https://github.com/moonbitlang/async)，Apache-2.0：提供 HTTP、
  网络、TLS、取消与超时，避免重复开发底层能力。

最小有用范围是安全获取清单。保留 JSON 使个人维护者不必生成和维护数千个 schema 类型。
只有明确、可测试的使用需求出现时才添加类型化辅助方法。

独立格式检查可运行 `python3 tools/test_reference.py`：下载 7 个 SHA-256 固定的
DMTF 公开 mockup，在本机回环服务上测试。该步骤本地可选、需要联网；Linux CI 通过
下方 GoFish 对照验证同一批输入。
范围与版权归属见 [docs/REFERENCE.md](docs/REFERENCE.md)，不代表真实设备验证。

小范围同场对照可运行 `python3 tools/test_gofish.py`，需要 Go 1.21+（已验证 Go 1.24.0）。
它将选定资产字段同时对照 GoFish v0.27.0 和固定原始样例，再在合成回环服务上验证共同的
分页、错误、会话与 TLS 行为。GoFish 仅是测试依赖，不是 MoonBit 库的运行时依赖。
Linux CI 运行该检查；结果、刻意保留的差异和局限见 [docs/COMPARISON.md](docs/COMPARISON.md)。

精简的可复现审阅步骤见 [docs/ACCEPTANCE.md](docs/ACCEPTANCE.md)。

贡献说明、安全政策见 [CONTRIBUTING.md](CONTRIBUTING.md)、[SECURITY.md](SECURITY.md)，
许可全文见 [LICENSE](LICENSE)。
