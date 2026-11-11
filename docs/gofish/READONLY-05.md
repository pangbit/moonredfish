# Task inventory reads / 任务清单读取

Read-only batch 05 · 2026-11-11 · GoFish v0.27.0 at
`4cc897fb5c172996e8f34a31a5d1012b45a287a7`.

Applications can discover the task service, read task status/progress/messages, enumerate
subtasks and inspect resources a task already created. All navigation is explicit. Reading
a TaskMonitor may have different protocol/lifecycle effects; this batch only retains its
URI as data and never polls it, starts/cancels a task or replays a payload.

应用可发现任务服务、读取状态/进度/消息、枚举子任务及任务已创建的资源。导航均为显式
读取，不轮询 TaskMonitor，不启动/取消任务或重放请求正文。TaskMonitor URI 仅作为数据。

The existing Field and strict integer contracts remain unchanged. The compatibility-mode
proposal is still pending. The user has now approved a conditional defect rule: confirmed
GoFish errors may follow the two specified DMTF implementations after verification, with
public exceptions. [The evidence gate and registry](EXCEPTIONS.md) record this rule;
no difference in this batch has been declared a verified exception.

三态和严格整数契约不变，兼容模式提议仍待决。用户新确认的缺陷原则是：确认 GoFish
有误，并与两个指定 DMTF 实现对照核实后，可按官方实现处理且公开例外。门槛及登记表
见上述链接；本批没有把任何差异宣布为已核实例外。

## Public reads / 公开读取

| API | Input and result / 输入与结果 |
| --- | --- |
| `Resource::task_service()` | TaskService view: overwrite policy, time, lifecycle event/enabled flags, deletion/monitor-expiry timing and selected Health / 服务策略、时间、标志、清理时限及健康 |
| `Resource::task()` | Task view: state/status, progress, start/end/estimated time strings, monitor URI, HidePayload flag and messages / 任务状态、进度、时间字符串、monitor URI、隐藏标志和消息 |
| `Client::task_service(root)` | ServiceRoot.**Tasks** singleton (not a guessed TaskService URI) / 沿服务根 Tasks 单链接 |
| `Client::tasks(service.resource)` | TaskService.Tasks collection / 任务集合 |
| `Client::sub_tasks(task.resource)` | Task.SubTasks collection once; no recursive descent / 一次子任务集合读取，不递归 |
| `Client::task_created_resources(task.resource)` | Task.Links.CreatedResources array, returned as Resource / 已创建资源链接数组，返回通用 Resource |

TaskService maps 7 selected properties, Task 9 and Message 9. Message exposes Message,
MessageId, MessageSeverity, legacy Severity, Resolution, Username, UserAuthenticationSource,
MessageArgs and RelatedProperties. Nested messages retain their full JSON; resource views
retain Resource. Message arguments, property pointers and task results preserve source
order. All enum-like, timestamp and duration strings remain uninterpreted.

三个视图分别映射 7、9、9 个属性。Message 分别保留新旧严重程度字段，参数与属性指针按
原顺序保留；嵌套原始 JSON 和资源 JSON 均可访问。未知状态、日期与时长不做推测或转换。

TaskState, TaskStatus, PercentComplete and message severities are independent reported
values. A Completed task with TaskStatus OK and a Critical message remains exactly that;
missing TaskStatus is not inferred. PercentComplete and the two service timeouts use the
existing nonnegative Int32 decoder. No 0–100 clamp or full schema/cross-field validation
is added: both clients accept PercentComplete=101 in the measured case. Go uint range
and lexical differences remain explicit, not an approved numeric migration.

状态、完成百分比和消息严重程度不互相覆盖，也不补推缺失值。三个数量字段沿用非负
Int32；不截断到 0–100，不进行完整 schema 或交叉字段验证。实测两端均接受 101，Go uint
范围与数字拼写差异仍待明确，未做数值契约迁移。

Navigation reuses existing per-call time/byte/member budgets, collection page/cycle bounds,
root-relative Redfish path validation and duplicate suppression. Four navigation calls
have separate budgets. No request is sent to TaskMonitor, Payload.TargetUri, a message's
ResolutionSteps.ActionURI or a child's SubTasks unless an explicit supported reader is
called for that resource. The count/presence-only offline example makes no connection.

四条导航复用现有预算、路径校验、分页/循环限制和去重，各次调用预算独立。消息中的动作
地址、请求正文目标、monitor 和子任务的后代链接不会被自动访问。离线示例只输出数量与
存在性。Raw JSON may include private task payloads, headers, message arguments or user
identifiers; it remains caller data, not a diagnostic dump or automatic redaction API.
原始数据可能包含任务正文、请求头、消息参数和账号标识；输出责任仍在调用方。

## Differential evidence / 差分证据

```sh
moon run examples/extended --target native
python3 tools/test_task.py
python3 tools/test_task.py --report /tmp/task-evidence.json
```

[Raw evidence](readonly-05.json) records inputs, typed projections/errors, actual GET traces,
fixture/source hashes and item IDs. The runner independently asserts expectations, member
request multiplicities and source result order without sorting away differences. Both
clients receive fresh GET-only loopback fixtures; no credentials, polling or controls.
The report's source hashes and subject_base_commit identify the tested implementation.

35 cases cover the three views, four navigations, pagination/order, null/defaults, message
array elements, unknown states, unsigned-number boundaries, unselected payload validation,
inline service data, duplicate links, path prevalidation and denied members/partial results.
Nine selected observations agree, four both reject with different error categories and
22 differ. All 46 native tests, mock integration and release build passed locally on macOS
arm64; Linux CI runs the same task comparison with the existing suites. The 34 new mapping
candidates produce **387 P / 11,193 U / 0 V**. These are functional observations, not whole
Task, Message, monitoring or GoFish equivalence.

35 场景验证三个视图、四条导航及上述边界，9 个选定观测相同、4 个两端拒绝但错误不同、
22 个有差异。本地 46 项 native、mock 和 release 构建通过；Linux CI 执行同一对照。
新增 34 个候选，总计 387 P / 11,193 U / 0 V，不表示完整任务或 GoFish 一致。

| Exact input / 确切输入 | GoFish | moonredfish | Open consequence / 未决影响 |
| --- | --- | --- | --- |
| Messages `[null]` | One zero-valued Message | InvalidResponse | D-JSON/null-object semantics |
| MessageArgs `[null]` | `[""]` | InvalidResponse | D-JSON/null-string semantics |
| PercentComplete `1.0` | JSON type error | Value(1) | D-NUM/lexical rules |
| PercentComplete `2147483648` | Exact uint on tested 64-bit platforms | InvalidResponse | D-NUM/native range |
| PercentComplete `101` | Value(101) | Value(101) | Neither selected decoder enforces schema range / 不证明 schema 合法性 |
| Completed + Critical message, TaskStatus absent | Empty TaskStatus | Missing | D-PRESENCE; neither derives Critical / 两端均不推导 |
| Payload `"not-an-object"` | Typed Task GET fails | Selected task fields remain readable; raw value retained | D-JSON/eager versus selected-field validation |
| Inline TaskService ServiceEnabled=true, linked value=false | Uses inline true, no GET | Fetches false | D-COLLECTION/B06/source selection |
| CreatedResources `[E0,E0]` | Two results/GETs | One result/GET | D-COLLECTION/duplicates |
| Tasks `[T0,403]` | T0 plus CollectionError | HTTP error with no returned array | D-COLLECTION/partial result |

No row is classified as a GoFish defect solely because the outputs differ. The proposed
DMTF exception gate applies to suspected defects; API translation and ordinary contract
differences still require their own decisions. Existing [issues](ISSUES.md) remain recorded.

不因为两方输出不同就认定 GoFish 错误；疑似缺陷进入两份 DMTF 参照门槛，普通 API 与契约
差异继续按原有决策处理，不以候选映射或测试数量充当完整一致。

## Remaining scope / 剩余范围

TaskMonitorInfo, Retry-After/polling and completion-response semantics, cancellation,
DeleteAllCompletedTasks, Update, typed Payload, ResolutionSteps/ActionInfoParameter,
message registry lookup, generic per-property ExtendedInfo and full Status remain gaps.
This Message view does not claim to resolve upstream #483, and raw retention does not
establish Go RawData/export/update semantics from #428. No real hardware or publication.

上述监控、控制、正文/解决步骤、注册表、逐属性扩展信息及完整健康模型仍是差距。Message
视图不宣称解决 #483，原始 JSON 不冒充 #428 的字节或更新语义。无实机或发布。

Pinned source headers and links: [Task.v1_7_4 / 2022.3](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/task.go),
[TaskService.v1_3_0 / 2025.4](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/taskservice.go),
[Message.v1_3_0 / 2024.3](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/schemas/message.go),
[Service.Tasks](https://github.com/stmcginnis/gofish/blob/4cc897fb5c172996e8f34a31a5d1012b45a287a7/serviceroot.go).
