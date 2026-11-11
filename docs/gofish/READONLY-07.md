# Virtual media inventory / 虚拟介质清单

Read-only batch 07 · 2026-11-11 · GoFish v0.27.0 at
`4cc897fb5c172996e8f34a31a5d1012b45a287a7` · [Raw evidence](readonly-07.json).

This batch connects System/Manager virtual media to the existing boot and certificate
inventory. It reads reported metadata and explicit collection links. It does not fetch
images, use media credentials, insert/eject media, change trust, configure TLS or invoke
ActionInfo convenience methods. The existing Field/strict-decoding contract is unchanged.

本批接通系统/管理器虚拟介质与已有启动、证书清单；读取报告元数据和显式集合链接。
不访问映像、不使用介质凭据、不挂载/弹出、不修改信任/TLS，不调用 ActionInfo 便捷方法。
保留现有三态与严格解码契约，不裁决兼容模式或尚未覆盖的官方数值字段契约。

## Public API / 公开 API

| API | Selected behavior / 选定行为 |
| --- | --- |
| `Resource::virtual_media()` | 14 reported fields plus 2 derived action-advertisement flags / 14 个报告属性与 2 个派生动作声明标志 |
| `Client::virtual_media(owner)` | Explicit ComputerSystem.VirtualMedia or Manager.VirtualMedia collection / 系统或管理器显式集合 |
| `Client::certificates(media)` | Existing reader reused for VirtualMedia.Certificates (server certificates) / 复用既有服务器证书集合读取 |
| `Client::virtual_media_client_certificates(media)` | VirtualMedia.ClientCertificates only / 仅客户端证书集合 |

Reported fields: ConnectedVia, EjectPolicy, EjectTimeout, Image, ImageName, MediaType,
MediaTypes, TransferMethod, TransferProtocolType, UserName, Inserted, VerifyCertificate,
WriteProtected and selected Status. All use Field. The original Resource/parsed JSON is
retained, including OEM and unselected fields. MediaType is a non-standard field documented
by the pinned reference; it remains independent from the supported MediaTypes array.
Unknown strings, empty strings, array order and duplicates remain unchanged.

14 个报告属性使用 Field，原资源及解析后 JSON 保留；非标准 MediaType 按固定参考读取，
不从 MediaTypes 推导。未知字符串、空值、数组顺序和重复保留，不自动修正相互矛盾的状态。

`supports_media_insert` and `supports_media_eject` are plain Bool, matching GoFish's
nonempty action-target test. Missing/null/empty target yields false; ActionInfo alone does
not indicate support. These flags ignore same-named top-level JSON fields and derive from
Actions. A nonempty target is metadata, not a validated safe URI, authorization, reachability
or a promise of action success. No method uses those targets to issue a request.

两个派生 Bool 按对应 Actions.target 是否非空计算；缺失/null/空字符串为 false，仅有
ActionInfo 不算支持。同名顶层 JSON 字段不决定结果；非空声明不是 URI 校验、权限、连通性
或动作成功保证。本批不使用这些 target 发出任何请求。

Image may be external, relative or null; it is returned without traversal or download.
UserName and unselected raw Password are caller data, not credentials for this client.
VerifyCertificate describes the service's media-server behavior and never changes the
client's verified HTTPS policy. Metadata and URLs can be private; the offline example
prints only synthetic presence/counts. No raw-data redaction or byte-identity claim is made.

Image 不被跟随；UserName 与原 JSON 内未选定的 Password 不作为本客户端认证信息。
VerifyCertificate 只描述服务端介质连接设置，不改变本客户端 HTTPS 校验。元数据/URL 可能
包含私密信息，离线示例仅打印合成存在性和数量；原 JSON 保留不代表脱敏或字节原样导出。

Collection reads reuse existing timeout, byte, page and unique-member budgets. Absent/null
links avoid collection requests. Server and client certificate links remain independent;
none is inferred from Image, the other collection, a conventional path or an action target.
The existing deduplication, all-or-error result and path restrictions remain measured
GoFish differences, not newly approved exceptions.

## Verification / 验证

```sh
moon run examples/extended --target native
python3 tools/test_virtual_media.py
python3 tools/test_virtual_media.py --report /tmp/virtual-media-evidence.json
```

Thirty loopback cases compare actual GoFish typed getters with native readers. Independent
expected projections and per-case GET multiplicities are asserted. Both System and Manager
entry points are exercised, as are distinct server/client certificate collections. No login,
write, Image GET, ActionInfo GET or action request occurs. GoFish can fetch collection
members concurrently; returned order and request multiplicity are checked separately.
The report includes exact fixtures, observed errors/values, request sequences and source
hashes plus subject_base_commit. All 52 native tests, checks, release build and the offline
example passed locally on macOS arm64. Linux CI runs this differential suite with existing
comparisons; the existing mock suite remains in both-platform CI.

30 个实际对照场景检查值、错误和请求次数；两条虚拟介质入口与两种证书来源均已执行。
52 项 native、检查、release 构建及离线示例本地通过；Linux CI 增加同一差分套件。
没有登录、写入、映像访问、ActionInfo 读取或动作调用。成员并发请求不冒充返回顺序变化。

**12 same selected observations, 5 both reject, 13 known differences.** The five both-reject
cases still have different error categories. **22 new candidates; 445 P / 11,135 U / 0 V.**
These counts are not complete resource/API equivalence or hardware certification.

**12 个选定观测相同、5 个双方拒绝、13 个已记录差异**；双方拒绝仍有错误分类差异。
新增 22 个候选，总计 **445 P / 11,135 U / 0 V**，不表示完整 API 一致或实机认证。

| Concrete input / 确切输入 | GoFish | moonredfish | Existing decision |
| --- | --- | --- | --- |
| Inserted absent / null | nil pointer in both cases | Missing / Null | D-PRESENCE |
| VerifyCertificate absent / null | false scalar in both cases | Missing / Null | D-PRESENCE; no TLS-setting inference |
| Explicit false for all 3 booleans | false | Value(false) | Same selected observation after projection |
| Image null | empty string | Null | D-PRESENCE |
| MediaTypes `[null]` | `[""]` | InvalidResponse | D-JSON |
| Password `123`, or action's `@Redfish.ActionInfo:123` | Whole typed GET fails | Selected view readable, raw retained | D-JSON / eager versus selected decoding |
| Only ActionInfo and top-level SupportsMediaEject=true | Derived eject flag false | Derived eject flag false | Nonempty action target controls advertisement |
| VirtualMedia collection `[M0,M0]` | Two items/GETs | One item/GET | D-COLLECTION |
| Collection `[M0,403]` | M0 plus CollectionError | HTTP error, no array | D-COLLECTION |
| ClientCertificates points to `/outside` | Fetches same-host path | InvalidPath before collection GET | D-SAFE |

## Remaining scope / 剩余范围

Password's typed/read-write behavior, all enum constants, complete Status, RawData byte
identity, update serialization, insert/eject/fallback behavior and ActionInfo APIs remain
unimplemented/unverified. The pinned EjectMediaActionInfo source selects insertMedia's
ActionInfo target; this is a [source-only candidate](ISSUES.md#virtual-media-actioninfo-source-candidate),
not a runtime comparison, approved exception or reason to copy/change behavior silently.
No new official numeric runs were needed: [previous observations](OFFICIAL-NUMBERS-01.md)
remain valid historical evidence with typed-field contracts unresolved.

Password 类型化/写入语义、完整枚举/Status、原字节、更新/动作/回退与 ActionInfo API 仍有
缺口。固定参考 EjectMediaActionInfo 使用 insertMedia 链接，仅登记源码候选；未执行、
未完成双 DMTF 核验，不作为例外或默改依据。数值证据沿用前批，不重复扩张验证。

Reference schema header: [VirtualMedia.v1_6_5 / 2022.3](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/virtualmedia.go).
[Consolidated review](DECISIONS.md) keeps unresolved choices grouped. No real-device
operation or Mooncakes publication was performed.
