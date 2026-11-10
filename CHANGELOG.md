# Changelog / 变更记录

## Unreleased

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
