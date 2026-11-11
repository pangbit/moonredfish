# Eject ActionInfo reference review / 弹出 ActionInfo 参考核验

2026-11-11 · [Raw report](action-info-routing-01.json) · [Exception gate](EXCEPTIONS.md).

**The user-approved two-DMTF exception condition is not met.** Two actual GoFish GET-only
cases confirm the suspect link selection. Both fixed official references were reviewed,
but no comparable VirtualMedia eject/insert ActionInfo selector was found in their reviewed
implementation surfaces. Generic URI/node lookup cannot supply the missing contract.
This report makes no official runtime, approved-exception, fix or latest-main claim.

**未满足用户确认的双 DMTF 例外条件。** 两个实际只读场景确认 GoFish 的链接选择；两套
固定官方源码已审阅，但对应 VirtualMedia 弹出/插入 ActionInfo 选择器未建立可比较契约。
通用 URI/节点查询不能补足该证据，不声称官方运行对照、例外成立、修复或最新主线行为。

## Fixed versions and coverage / 固定版本与覆盖

| Reference | Commit | Evidence / 证据 |
| --- | --- | --- |
| GoFish v0.27.0 | `4cc897fb5c172996e8f34a31a5d1012b45a287a7` | Two actual EjectMediaActionInfo calls against synthetic loopback HTTP / 两个实际回环读取 |
| DMTF/Redfishtool | `8c46f567aa9c960851108e43bf23fd6a64c37897` | Source review of all 10 tracked redfishtoollib Python files / 10 个核心 Python 源码审阅 |
| DMTF/libredfish | `f9a23c33d46afe15f09b604160c09a320f1c769c` | Source review of all 23 tracked C/header files under include and src / include、src 共 23 个 C/头文件审阅 |

The runner requires exact clean official checkouts, records hashes for every scanned file
and line-numbered symbol hits, and asserts the observed pinned source inventory. Symbol
search supports the coverage audit; absence of a token alone is not a semantic proof about
all possible generic programs, other releases or external consumers. No reference source
was modified. GoFish execution used Go 1.24.0 on local macOS arm64; this opt-in review is
separate from ordinary Linux CI and the official numeric runtime report.

核验固定提交并要求官方工作树干净，记录扫描文件哈希及命中行。关键词检索辅助覆盖审阅，
不把关键词缺失当成对任意通用程序、其他版本或外部调用方的语义证明。不修改官方源码。
GoFish 两场景在本地 macOS arm64 / Go 1.24.0 运行，未冒称本次官方端实际执行或 Linux 覆盖。

## Actual GoFish results / GoFish 实测

| Exact advertised metadata / 明确输入 | EjectMediaActionInfo observation / 实际观测 |
| --- | --- |
| Insert annotation `/redfish/v1/ActionInfoRoutingTests/Metadata/Insert`; Eject annotation ending `/Metadata/Eject` | GETs Insert; returns resource Id=Insert; never GETs Eject / 读取并返回 Insert |
| Only Eject annotation ending `/Metadata/Eject` | Returns unsupported error; makes no metadata GET / 报不支持，不请求元数据 |

Both owners omit action targets. No insert/eject operation is invoked. The fixture checks
all request methods/paths and zero login/logout counts; both metadata responses contain
an empty Parameters array, so the returned identity and trace expose the selection directly.
The [pinned method](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/virtualmedia.go#L278)
checks and reads insertMedia.ActionInfoTarget. This establishes the method's measured
behavior, not completion of the user's required official-reference comparison.

两个资源均不提供控制 target；从不调用插入/弹出操作。请求轨迹和返回 Id 直接显示选择，
并检查零登录/注销。已复现的是固定方法行为，不等于完成用户要求的官方参考核验。

## Why official coverage is insufficient / 官方覆盖为何不足

Redfishtool's [generic helper](https://github.com/DMTF/Redfishtool/blob/8c46f567aa9c960851108e43bf23fd6a64c37897/redfishtoollib/redfishtoolTransport.py#L1272)
accepts an already selected relPath and parameter name. Its callers in
[Systems](https://github.com/DMTF/Redfishtool/blob/8c46f567aa9c960851108e43bf23fd6a64c37897/redfishtoollib/Systems.py) and
[Managers](https://github.com/DMTF/Redfishtool/blob/8c46f567aa9c960851108e43bf23fd6a64c37897/redfishtoollib/Managers.py)
select reset or boot metadata; the reviewed modules have no corresponding VirtualMedia
selector. Running raw GET with a manually chosen eject URI would test our choice, not
an equivalent official method. No reset/boot command was run because those paths can write.

Redfishtool 通用 helper 接收已选定 relPath；已审阅调用方处理 reset/boot，没有对应虚拟
介质选择器。手工指定 Eject URI 再 raw GET 只能验证调用方选择，不能冒充等价官方方法。
未运行可能写入的 reset/boot 命令。

libredfish's [payload API](https://github.com/DMTF/libredfish/blob/f9a23c33d46afe15f09b604160c09a320f1c769c/include/redfishPayload.h)
and [service API](https://github.com/DMTF/libredfish/blob/f9a23c33d46afe15f09b604160c09a320f1c769c/include/redfishService.h)
provide generic node/path/resource operations. The reviewed public headers and C sources
have no dedicated VirtualMedia/ActionInfo selector. Manually traversing the Eject node
would again inject the harness's choice. No hand-written selector substitutes for libredfish.

libredfish 提供通用节点/路径/资源操作；已审阅头文件及 C 源码未提供专用选择器。手工
遍历 Eject 节点仍由夹具决定，不以手写选择器冒充官方实现。

Recommendation: retain this reproducible candidate and keep EjectMediaActionInfo unmapped
until comparable official evidence satisfies the user's gate, or the user explicitly changes
that rule. The independent named-annotation reader in [batch 08](READONLY-08.md) exposes
caller-directed reads; it is not registered as that method's compatibility implementation.
No new compatibility decision is assumed and no control or hardware access is needed now.

建议保留可复现候选，等待可比较官方证据或用户明确修改规则；对应方法仍未映射。本批按
调用方名称读取的通用 API 不登记为该方法兼容实现，不预设裁决，不需控制或实机操作。

## Reproduce / 复现

```sh
python3 tools/test_action_info_references.py \
  --redfishtool /tmp/moonredfish-official-numbers/redfishtool \
  --libredfish /tmp/moonredfish-official-numbers/libredfish \
  --report /tmp/action-info-routing.json
```

Use clean checkouts at the commits above. No official build, installation or runtime is
required for this source-coverage audit. The GoFish executable is temporary; endpoints are
created internally and restricted to numeric loopback. **Zero verified exceptions.**

官方部分为源码覆盖审阅，无需构建/安装或运行；GoFish 可执行文件临时生成，端点仅内部
数值回环。**零个已核实例外**。无实机或 Mooncakes 发布。
