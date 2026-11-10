# moonredfish

[English](README.mbt.md)

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

正式发布到 registry 后可执行 `moon add pangbit/moonredfish`；发布前请通过 MoonBit
本地 workspace 依赖使用。在调用方 `moon.pkg` 中导入 `pangbit/moonredfish`。
英文文档包含编译检查过的最小解析示例。

native 异步应用创建 `Client::new("https://bmc.example.invalid")`，再调用
`service_root()`、`systems()`、`chassis()`、`managers()`、`get(path)` 或
`members(path)`。包含 `async fn main` 的包还需导入 `moonbitlang/async`。
`members` 只返回成员 URI，清单方法会继续逐一获取资源。

```sh
# 仅在已获得目标设备访问授权时使用。此示例为匿名 HTTPS 请求。
moon run examples/inventory --target native -- https://authorized-bmc.example.invalid
```

需要认证时，由应用提供凭据调用 `login(username, password)`，读取完成后调用
`logout()`，并在应用自己的异常与取消清理路径中处理会话退出。库不后台重新登录，
也不自动退出会话。登录使用标准 `/redfish/v1/SessionService/Sessions`，暂不支持其他
会话 URI 约定。同一客户端的登录/退出必须串行，且不可与该客户端其他请求重叠。
登录失败或取消时，远端可能已经创建会话，只是响应尚未返回。不要自动重试；应通过
已授权的管理工具检查会话状态。

## 安全默认值与限制

- 构造客户端不会发起连接。默认只允许 HTTPS；只有显式设置
  `allow_loopback_http=true` 才能访问本机回环 HTTP mock。不提供跳过 TLS 验证的选项。
  `ca_file=...` 可指定由应用管理的 PEM CA 文件。
- 自动访问的链接必须为同源 `/redfish/v1` 相对路径。拒绝绝对 URL、编码的路径片段、
  路径穿越、片段标记、反斜杠和控制字符；查询串允许百分号编码。
  这是有意选择的严格子集，可能拒绝部分厂商返回的合法但不受支持的 URI。
- 默认单次请求 10 秒超时、正文最多 4 MiB、集合最多 100 页。每次请求后关闭连接，
  无连接池和缓存。
- GET 非 2xx 状态返回 `HttpStatus(status)`，不会在错误中包含响应正文。
  JSON 必须是合法 UTF-8，且不可含重复键。暂不解码完整 Redfish 错误消息注册表；
  网络与 TLS 错误保留官方 async 库的错误类型。
- 缺失属性保持缺失，不编造默认值。原始 `Resource.json` 可能包含私密资产信息，
  应用在记录或分享前必须脱敏。不要提交真实凭据、令牌、硬件标识、内网主机名或抓包。

## 验证

```sh
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
HTTP 错误、正文/页数/时间限制、不可信证书拒绝与指定 CA 的 HTTPS 成功路径。
所有凭据与设备信息均为合成数据。脚本不访问真实设备或外部测试服务。
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

贡献说明、安全政策见 [CONTRIBUTING.md](CONTRIBUTING.md)、[SECURITY.md](SECURITY.md)，
许可全文见 [LICENSE](LICENSE)。
