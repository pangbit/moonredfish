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

## Evidence map / 证据对应

| Claim / 声明 | Check / 检查 |
| --- | --- |
| Optional fields and strict JSON / 可选字段与严格 JSON | Unit tests and compiled README example / 单测与 README 编译示例 |
| Systems, Chassis, Managers / 三类资产清单 | Synthetic collections and resource GETs / 合成集合与资源读取 |
| Safe pagination / 安全分页 | Next links, duplicate suppression, cycles, page limits, unsafe URI rejection / 下一页、去重、循环、上限与危险 URI 拒绝 |
| Verified HTTPS / HTTPS 验证 | Untrusted certificate rejection, custom CA success, hostname mismatch rejection / 不可信证书拒绝、自定义 CA 成功、主机名不匹配拒绝 |
| Authentication lifecycle / 认证生命周期 | Login errors, token use, logout, authenticated executable cleanup after success and failure / 登录错误、令牌使用、退出及示例成功/失败清理 |
| Bounded requests / 有限请求 | Timeout, body limit, no redirect following / 超时、正文限制、不跟随重定向 |
| Output minimization / 输出最小化 | Example prints counts; tests exclude synthetic passwords, tokens and private response bodies / 示例仅打印数量，测试排除合成密码、令牌与私密响应正文 |

The GitHub Actions workflow repeats these checks on Linux x86_64 and macOS arm64.
Inspect the workflow result for the exact commit under review, not just the presence of
a workflow file. `moon package --list` is packaging, not registry publication.
GitHub Actions 在 Linux x86_64 与 macOS arm64 重复这些检查。请查看待审提交对应的实际结果，
不能只看工作流文件是否存在。`moon package --list` 仅打包，不发布到 registry。

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
