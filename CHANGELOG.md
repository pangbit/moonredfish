# Changelog / 变更记录

## Unreleased

- Add read-only TaskService/Task/Message views and four bounded navigation APIs, with
  task state/progress/message and request-trace comparisons. Retain defaults, uint range,
  eager-decoding and partial-result differences; no task monitor polling or controls.
  Record the user-approved two-DMTF defect exception gate; no verified exception yet.
- 新增任务服务、任务和消息只读视图及四条有界导航，对照状态/进度/消息和请求轨迹；
  保留默认值、整数范围、整对象解码和部分结果差异，不轮询或控制任务。
  记录用户确认的双 DMTF 缺陷例外门槛，目前尚无已核实例外。

- Add read-only Boot, BootOption, SecureBoot, SecureBootDatabase and Signature views
  with four bounded navigation APIs. Compare both GoFish BootOptions entry points;
  retain presence, strictness and inline-data differences. Review upstream issues and
  verify raw annotations/current Boot versus Settings without any control calls.
- 新增启动配置、启动选项、安全启动、数据库和签名只读视图及四条有界导航，
  对照 GoFish 两条 BootOptions 入口；保留三态、严格解码与内嵌数据差异。
  核对上游 issues，定向验证注解/原始数据和当前 Boot 与 Settings 的区分，不执行控制。

- Add selected read-only PCIeDevice/PCIeFunction/PCIeInterface views and five explicit
  system/chassis/device/function navigation APIs. Reuse bounded link-array traversal;
  verify reference source priorities and record vendor numeric/partial-result differences.
- 新增 PCIe 设备、功能和接口选定视图及五条显式导航 API，复用有界链接数组遍历；
  对照固定参考的来源优先级，保留厂商数值转换、默认值及部分结果差异并合并审阅建议。

- Add typed read-only Ethernet DHCPv4/DHCPv6, SLAAC, DNS and interface policy fields,
  nested raw-JSON retention and owner-link differential verification. Keep unresolved
  default/null-element behavior explicit; no configuration writes or full-parity claim.
- 新增以太网 DHCPv4/DHCPv6、SLAAC、DNS 与接口策略类型化读取，保留嵌套原始 JSON，
  补充显式链接差分验证；默认值和 null 成员差异继续开放，不执行配置写入。

- Preserve wire JSON numeric spelling and reject fractional counts/capacities hidden by
  floating-point rounding. Existing integer ranges and integral decimal/exponent behavior
  remain unchanged. Add 39 read-only differential cases, item-level evidence and open
  GoFish compatibility decisions; no full-parity claim, device controls or publication.
- 保留 HTTP JSON 数字原文，修复浮点舍入掩盖非整数容量/数量的问题；既有范围与数学整数
  拼写规则不变。新增 39 个只读差分场景、逐项证据及待决兼容取舍，不宣称完整对齐。

- Added bounded read-only Storage/Drive/Volume, EthernetInterface/NetworkAdapter,
  LogService/LogEntry, SoftwareInventory and current BIOS attribute views and explicit
  link readers. Added a count-only example, three-state/budget regression checks and
  pinned DMTF/GoFish comparisons. No device-control APIs or registry publication.
- 新增有界的存储/磁盘/卷、网络、日志、固件和当前 BIOS 属性只读视图及显式链接 API；
  补充仅输出数量的示例、三态/预算回归及 DMTF/GoFish 对照，无设备控制或 registry 发布。

- Add typed System/Chassis/Manager, Processor/Memory, legacy Thermal/Power and modern
  Sensor/Fan/PowerSupply inventory views with raw JSON, explicit Missing/Null/Value
  semantics and bounded advertised-link traversal. / 新增类型化资产/健康视图，保留原始
  JSON，明确三态值，并以受限请求跟随显式链接。
- Add an offline/HTTPS hardware example, focused value/link regression tests, expanded
  pinned DMTF/GoFish comparison and bilingual inventory guide. / 新增硬件示例、聚焦回归、
  扩展固定参考对照及双语说明。仍未验证真实 BMC；未发布到 Mooncakes。


- Add a pinned GoFish comparison for selected DMTF inventory fields and shared synthetic HTTPS/session/error behavior.
- 新增固定版本 GoFish 同场对照，验证选定 DMTF 清单字段和共同的合成 HTTPS、会话及错误行为。

- Reject session discovery targets outside an explicit Sessions collection before sending credentials.
- 发送认证请求前拒绝不明确指向 Sessions 集合的发现链接。

- Add a hash-pinned independent DMTF mockup check without vendoring third-party documents.
- 新增固定哈希的独立 DMTF mockup 检查，不在项目中分发第三方原始文档。

- Add cancellation-safe scoped sessions, lifecycle overlap protection and explicit logout retry/expiry tests.
- 新增取消安全的作用域会话、生命周期并发保护，以及退出重试/过期验证。

- Discover the login collection through ServiceRoot Links.Sessions and validate logout against that collection.
- 从 ServiceRoot Links.Sessions 发现会话集合，并据此约束退出目标。

- Bound complete collection/inventory operations by deadline, unique members and total response bytes.
- 为完整集合/清单操作增加总时限、唯一成员数和累计响应正文上限。

- Add opt-in bounded Redfish error codes and MessageId diagnostics without retaining free-form bodies.
- 新增可选的有限 Redfish 错误代码与 MessageId 诊断，不保留自由文本正文。

- Add an authenticated HTTPS inventory example with bounded session cleanup on exit.
- Exercise the example's success/error cleanup and output redaction with synthetic TLS fixtures.
- Add explicit hostname-mismatch rejection to the TLS integration test.
- Add concise bilingual acceptance instructions; registry releases remain maintainer-operated.

新增带会话清理的认证 HTTPS 清单示例，验证成功/失败清理和输出脱敏，补充 TLS 主机名
不匹配拒绝测试及精简双语验收说明。此部分尚未发布，Mooncakes 发布由维护者手动执行。

## 0.1.0 — 2026-11-10

- Native read-only Redfish inventory, safe link handling and bounded pagination.
- Session lifecycle, verified TLS, per-request timeout and body-size limits.
- Offline and HTTPS inventory examples; synthetic HTTP/HTTPS integration tests.
- English and Simplified Chinese documentation.

原生只读清单、安全链接和有限分页；会话生命周期、TLS 验证、请求超时及正文限制；
离线与 HTTPS 示例、合成 HTTP/HTTPS 集成测试；中英双语文档。该初版仅覆盖只读清单与会话生命周期，不宣称真实 BMC 兼容。
