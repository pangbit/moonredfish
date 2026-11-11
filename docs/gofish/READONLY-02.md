# Ethernet configuration reads / 以太网配置读取

Read-only implementation batch 02 · 2026-11-11 · GoFish v0.27.0, commit
`4cc897fb5c172996e8f34a31a5d1012b45a287a7` · EthernetInterface.v1_12_4 (2023.3).

The library now exposes DHCPv4, DHCPv6, SLAAC, DNS server lists and interface policies
through `Resource::ethernet_interface()` and the existing
`Client::ethernet_interfaces(owner)` traversal. These are real typed read APIs; no
network configuration is applied. Existing Field/default, authentication, transport and
collection behavior remain the basis of this additive implementation.

本批实际增加 DHCPv4、DHCPv6、SLAAC、DNS 列表及接口策略读取，既可从已读资源解码，也可
经已有 owner→集合→接口路径获取。沿用 Field 表示、认证、传输和集合行为，不执行配置写入。

## Implemented surface / 实现范围

| API | New readable fields / 新增可读字段 |
| --- | --- |
| `EthernetInterface` | `auto_neg`, `dhcpv4`, `dhcpv6`, `ethernet_interface_type`, `ipv6_default_gateway`, `ipv6_enabled`, `name_servers`, `routing_scope`, `stateless_address_auto_config`, `static_name_servers`, `team_mode`, `uefi_device_path` |
| `DHCPv4Configuration` | `dhcp_enabled`, `fallback_address`, `use_dns_servers`, `use_domain_name`, `use_gateway`, `use_ntp_servers`, `use_static_routes` |
| `DHCPv6Configuration` | `operating_mode`, `use_dns_servers`, `use_domain_name`, `use_ntp_servers`, `use_rapid_commit` |
| `StatelessAddressAutoConfiguration` | `ipv4_auto_config_enabled`, `ipv6_auto_config_enabled` |

All 14 declared fields of the three nested reference configuration structures have a
read mapping. Each nested view retains its original `json`; fields are Missing, Null or
Value. Enum strings remain open, DNS arrays preserve order and duplicates, and empty
arrays remain values. There is no IP validation, DNS resolution, inferred enablement or
implicit configuration update. DNS names/addresses remain caller data and the example
prints only presence/counts.

三个嵌套参考结构的 14 个公开字段均有读取映射；新增 12 个接口字段。嵌套对象保留原始
JSON，未知枚举原样保留，DNS 数组不排序、不去重。空数组是有效值；不解析 DNS、不验证 IP、
不推断开关状态、不触发 Update。例子仅输出存在性和数量，不打印网络地址。

This does not complete EthernetInterface: address/prefix/policy arrays, MTU/VLAN and
related resource navigation, exposed enums/constants, update serialization and `Update`
remain outstanding. New fields use the existing strict typed decoder: wrong types now
fail when this extended view is requested. Go struct defaults and its permissive JSON
cases are still open compatibility decisions, not claimed equivalents.

这不是 EthernetInterface 全量完成：地址/前缀/策略数组、MTU/VLAN、关联资源、公开枚举
常量、写入序列化及 Update 仍待实现。新增可读字段类型错误会使该类型化视图解码失败。
Go 默认值及宽松解析差异继续开放，不能把读取字段映射当成完整行为一致。

## Evidence / 验证证据

```sh
moon run examples/extended --target native
python3 tools/test_network_config.py
# Save a fresh source-stamped report:
python3 tools/test_network_config.py --report /tmp/network-config.json
```

[Raw evidence](readonly-02.json) records exact inputs, focused outputs, error categories,
item IDs, request sequence, toolchain and source hashes. It was produced on macOS arm64
with Go 1.24.0 and MoonBit native 0.10.20+65efd5b93. The containing commit identifies the
batch; `subject_base_commit` plus source hashes identify the tested changes. Linux CI
runs the same feature suite. The prior batch's source hashes remain historical snapshots.

A complete defined fixture traverses a ComputerSystem link and collection, then exercises
every added value through both typed clients. Other cases cover absent/null/empty nested
objects, every added property's wrong type, future enum strings and DNS member errors.
The runner checks the entire returned projection and the exact GET sequence; the report
keeps each case's focus fields and parent objects without normalizing states or values.

原始证据记录确切输入、输出、错误类别、条目 ID、请求序列及源码/环境哈希。完整配置夹具
通过系统显式链接和集合读取全部新增字段；其余夹具覆盖缺失/null/空对象、每个新增字段的
错误类型、未知枚举和 DNS 数组成员。runner 验证完整输出与精确 GET 序列，报告保留各场景
聚焦字段和父对象，不归一化字段状态或值。所有数据均为合成回环数据。

All 37 native tests passed locally, including raw-data retention, nested presence and
malformed-field regressions. The differential suite has 40 cases: one fully supplied
configuration projection agrees, 28 both reject with their own error types, and 11 expose
known differences. This is evidence for specific read behavior, not a completion percentage.
At this batch's commit, 29 previously unmapped declarations gained candidate mappings: **263 P / 11,317 U / 0 V**.

本地 37 项 native 测试通过。40 个差分场景中，完整有值配置投影相同，28 个两端拒绝但错误
类型不同，11 个存在已知差异。这些结果说明具体读取行为，不表示一致性百分比；29 个声明
从未映射进入候选映射，仍无完整验证的 V 项。

## Decisions with concrete inputs / 具体输入与待决取舍

| Input / 输入 | GoFish v0.27.0 | moonredfish | Impact and recommendation / 影响与建议 |
| --- | --- | --- | --- |
| `{ "DHCPv4": null }` | Zero-valued configuration: booleans false, FallbackAddress empty / 零值配置 | `dhcpv4 = Null` | Explicit null can be confused with a disabled configuration. Apply the pending D-PRESENCE translation decision consistently; preserve current Field API until then / null 与禁用配置可能混淆，统一裁决 D-PRESENCE，当前先保留 Field |
| `{ "DHCPv6": {} }` | OperatingMode empty and flags false / 空模式、标志 false | Configuration Value, all nested fields Missing / 配置存在，子字段缺失 | Caller-visible defaults differ even for a present object. Recommend explicit nested scalar-default mapping for a future approved GoFish-compatible API / 建议在获批兼容 API 中明确嵌套标量默认值 |
| `{ "NameServers": [null] }` (also StaticNameServers) | `[]string{""}` | `InvalidResponse` | Go accepts an unusable empty DNS entry. Keep strict behavior pending D-JSON; matching Go requires an explicitly approved null-element rule, not an undocumented coercion / Go 接受空 DNS 项；等待 D-JSON 明确规则，不静默转换 |
| `{ "IPv6DefaultGateway": "2001:db8::1" }` | IPv6Enabled is false (Go zero value) / false | `ipv6_enabled = Missing` | Pinned source comment says absent IPv6Enabled with other IPv6 data is assumed true, but the actual Go decoder does not infer it. For compatibility use measured Go behavior after D-PRESENCE approval; do not silently synthesize true from the comment / 注释与实际解码不同；兼容目标以实测 Go 为准，不凭注释自动补 true |
| `{ "AutoNeg": true }` with TeamMode absent | TeamMode is empty string; source comment describes assumed None / 空串，注释称默认 None | `team_mode = Missing` | Empty, missing and None are distinct observations. Preserve the distinction until default translation is approved / 空串、缺失与 None 不同，默认映射须明确决定 |

These decisions do not block independent read fields. Numeric/address-slot/collection
contracts remain in the [full parity plan](../GOFISH_PARITY.md) and [batch 01](READONLY-01.md).
No authentication downgrade, physical control or registry publication was performed.
这些决策不阻塞独立字段读取；数值、地址空槽和集合契约继续单列。无认证降级、实机控制或发布。

Source: [pinned EthernetInterface declarations and decoder](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/ethernetinterface.go).
The default assumptions above quote the source's meaning, not proof of runtime inference
or full DMTF conformance.
