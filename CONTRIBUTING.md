# Contributing / 贡献指南

This is a personally maintained project. Keep patches small and explain the use case.
Add a focused regression test for behavior changes; update both English and Chinese
public documentation when the contract changes. Do not add generic frameworks without
an actual supported use case. Open an issue before proposing device-mutating APIs.

这是个人维护项目。请提交小而聚焦的改动，说明真实使用需求；行为变化需要回归测试，
契约变化需同步中英文文档。没有实际需求时不要添加通用框架。涉及设备写操作的 API
请先讨论，不要把它与清单读取混为一谈。

Before a pull request / 提交前运行：

```sh
moon update
moon check --target native --deny-warn
moon test --target native --deny-warn
python3 tools/test_mock.py
moon info --target native
moon fmt --check
moon package --list
```

Use synthetic fixtures only. Review the staged diff and packaged file list for passwords,
tokens, private hosts, local paths, hardware identifiers, and unrelated files. Do not
commit raw device captures, environment files, private keys, build outputs or agent notes.
Contributions are distributed under Apache-2.0. Be respectful; there is no promised SLA.

只使用合成测试数据。检查暂存 diff 和打包文件清单，确保无密码、令牌、内部地址、本机路径、
硬件标识和无关文件。禁止提交设备原始抓包、环境文件、私钥、构建产物或私人代理笔记。
贡献按 Apache-2.0 分发。请保持友善；个人项目不承诺响应时限。

## Releases / 发布

Registry publication is a manual maintainer action. CI checks and packages the source,
but never publishes to Mooncakes. Contributors and automation must not run publication
commands on the maintainer's behalf. The existing 0.1.0 release remains available;
changes listed as Unreleased are source-only until the maintainer publishes a new version.

Mooncakes 发布由维护者手动执行。CI 仅检查与打包，不执行发布；贡献者与自动化不得代替
维护者执行发布命令。现有 0.1.0 保留，Unreleased 改动在维护者发布新版本前仅存在于源码。
