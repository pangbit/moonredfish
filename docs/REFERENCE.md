# Independent reference check / 独立参考验证

`python3 tools/test_reference.py` downloads exactly seven public mockup JSON files from
[DMTF/Redfish-Mockup-Server, public-rackmount1](https://github.com/DMTF/Redfish-Mockup-Server/tree/23d21f9a3610f6b6fbb71ffc941296b159a524d2/public-rackmount1),
commit `23d21f9a3610f6b6fbb71ffc941296b159a524d2` (2026-09-04). The filenames and SHA-256
values are fixed in the script. It refuses modified, oversized or unavailable inputs,
serves the original bytes on loopback, and exercises the actual MoonBit client. Network
access to GitHub is required; there is no live BMC connection and no fallback that silently
replaces an upstream sample with a synthetic one.

该命令只下载上述固定提交中的 7 个公开 JSON 样例，文件名与 SHA-256 固定在脚本中。
输入被修改、过大或无法获取时会失败，不会静默改用自造数据。原始字节通过本机回环服务
提供给实际 MoonBit 客户端。需要访问 GitHub，但不会连接真实 BMC。

Selected inputs / 所选输入：

- ServiceRoot: `index.json`
- Systems: `Systems/index.json`, `Systems/437XR1138R2/index.json`
- Chassis: `Chassis/index.json`, `Chassis/1U/index.json`
- Managers: `Managers/index.json`, `Managers/BMC/index.json`

## What it establishes / 能证明什么

It independently checks ServiceRoot discovery, three collection shapes, member traversal,
and resource identity/type preservation without relying exclusively on our synthetic
fixtures. Each selected collection contains one member. This is **not** a test of
pagination, authentication, TLS, firmware, vendor support or complete Redfish conformance.
The separate synthetic suite checks our security and failure-handling contracts. We do
not use the upstream mock server's session implementation as a normative authority.

验证服务根发现、三类集合格式、成员访问及资源标识/类型保留，避免所有假设都来自本项目
自建 mock。每个所选集合只有一个成员，因此该测试**不验证**分页、认证、TLS、固件、厂商
支持或 Redfish 完整符合性。安全与异常契约由独立的合成测试覆盖，不把上游模拟器的会话
实现当作规范依据。

## Attribution and copyright / 归属与版权

The original samples retain their `@Redfish.Copyright` fields and remain in memory only;
they are not copied into this repository, distribution archive or generated evidence
files. DMTF's source repository has a BSD-3-Clause license, but sample document notices
also refer to the [DMTF copyright policy](https://www.dmtf.org/about/policies/copyright).
Our Apache-2.0 license does not relabel those third-party samples. This standards and
interoperability check retains the source/version attribution above and does not alter
their content or imply DMTF endorsement.

原始样例保留 `@Redfish.Copyright` 字段且仅驻留内存，不加入本仓库、分发包或生成的证据
文件。上游仓库采用 BSD-3-Clause，但样例文档还附带 DMTF 版权政策声明。本项目的
Apache-2.0 不会替换这些第三方声明。此标准与互通检查保留上方来源和版本信息，不修改
样例，也不暗示 DMTF 背书。

Session discovery, extended error information and opaque pagination links were reviewed
against [DMTF DSP0266 1.20.1](https://redfish.dmtf.org/schemas/DSP0266_1.20.1.html).
Reading selected requirements is not an exhaustive compliance audit.
会话发现、扩展错误信息和不透明分页链接对照 DSP0266 1.20.1 核查，但不代表穷尽式符合性审计。
