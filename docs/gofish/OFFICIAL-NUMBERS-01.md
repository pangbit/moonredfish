# Same-input official numeric checks / 官方同输入数值核验

2026-11-11 · [Raw report](official-numbers-01.json) ·
[User-approved exception gate](EXCEPTIONS.md).

Eight numeric inputs were actually executed through pinned GoFish, moonredfish,
DMTF Redfishtool and DMTF libredfish. Both official generic read paths preserve the
integer 16777217, while GoFish's PCIeInterface decoder produces 16777216. This establishes
a concrete value-preservation difference at those entry points. It does **not** establish
an equivalent PCIe/Task typed validation/coercion contract in the official clients, or
that every synthetic boundary lies inside the field's normative domain. **Zero verified
typed-behavior exceptions are declared.** Existing decoding remains unchanged.

8 个输入已在四方实际运行。两个官方通用读取路径保留整数 16777217，GoFish PCIeInterface
解码则得到 16777216。已确认的是这些入口的数值保留差异；尚未确认官方同形 PCIe/Task
字段校验、转换契约，也未把全部探针认定为字段语义域内的有效输入。**不宣布已核实例外**，
现有解码不变。

## Versions and executed paths / 版本与实际入口

| Implementation | Fixed source | Actual operation |
| --- | --- | --- |
| GoFish v0.27.0 | `4cc897fb5c172996e8f34a31a5d1012b45a287a7` | Typed GetPCIeDevice / GetTask through existing comparison adapters |
| moonredfish | report subject_base_commit plus source hashes | Client GET + selected PCIe/Task views |
| [DMTF/Redfishtool](https://github.com/DMTF/Redfishtool/tree/8c46f567aa9c960851108e43bf23fd6a64c37897) | `8c46f567aa9c960851108e43bf23fd6a64c37897` | Real CLI `raw GET`, anonymous numeric loopback HTTP, no proxy, dump or async wait |
| [DMTF/libredfish](https://github.com/DMTF/libredfish/tree/f9a23c33d46afe15f09b604160c09a320f1c769c) | `f9a23c33d46afe15f09b604160c09a320f1c769c` | Real shared library: createRedfishPayloadFromString, payloadToString, getPayloadByNodeNameNoNetwork and public numeric/bool accessors; service=NULL |
| [Jansson 2.14](https://github.com/akheron/jansson/tree/684e18c927e89615c2d501737e90018f4930d6c5) | `684e18c927e89615c2d501737e90018f4930d6c5` | Built dependency used by libredfish, not a substitute implementation |

The harness requires the exact commits and clean reference checkouts. No official source
is vendored or patched. A fresh GET-only fixture serves each selected case's identical
UTF-8 bytes to GoFish, native and Redfishtool; the same bytes are passed directly to the
libredfish public payload decoder. Thus libredfish HTTP/redirect/auth behavior is **not**
covered. Type and value are both compared so JSON 1.0 is not silently equated to integer 1.
Actual method/path traces, wire hashes, typed outputs and the library binary hash are saved.

夹具向三个网络读取端提供相同字节，libredfish 实际 payload 解码器读取同一字节串，不用
手写 JSON 模拟替代库。libredfish 的 HTTP、跳转和认证行为不在本核验内。报告同时记录
类型与值、请求轨迹、输入和源码哈希，避免把 1.0 与整数 1 的差异抹平。

Local environment: macOS arm64, Python 3.9.6, Go 1.24.0, Apple clang 21.0.0, CMake 4.2.3.
Python dependency versions are in the report, including requests 2.32.5 and python-dateutil
2.9.0.post0. Jansson and libredfish were built in a temporary directory; OpenSSL include,
crypto-link and Jansson runtime paths were supplied to upstream CMake for macOS. No system
installation or reference source edit was made. These official checks have not run on Linux;
ordinary repository CI continues separately and does not imply that coverage.

官方运行证据目前仅覆盖 macOS arm64；普通 Linux CI 通过不等于此官方核验已在 Linux 运行。
依赖隔离在临时目录，构建参数处理 macOS 头文件/链接/runtime 路径，不修改官方源码。

## Observations / 实测结果

`raw` below means the JSON type/value returned through the official generic path.
The libredfish numeric getters are separate APIs, not schema-aware PCIe/Task decoders.

| Input property/value | GoFish typed | moonredfish typed | Redfishtool raw + libredfish parsed | libredfish accessor result |
| --- | --- | --- | --- | --- |
| LanesInUse `16777217` | 16777216 | 16777217 | integer 16777217 | int and long-long: 16777217 |
| LanesInUse `"8"` | 8 | InvalidResponse | string `"8"` | integer getters: 0 |
| LanesInUse `"not-a-number"` | 0 | InvalidResponse | original string | integer getters: 0 |
| LanesInUse `true` | 0 | InvalidResponse | boolean true | integer getters: 0; boolean=true with type flag=true |
| LanesInUse `1.5` | 1 | InvalidResponse | real 1.5 | integer getters: 0; double=1.5 with type flag=true |
| PercentComplete `1.0` | JSON type error | 1 | real 1.0 | integer getters: 0; double=1.0 with type flag=true |
| PercentComplete `2147483648` | 2147483648 | InvalidResponse | integer 2147483648 | long-long: 2147483648; int: -2147483648 on this build |
| PercentComplete `101` | 101 | 101 | integer 101 | integer getters: 101 |

The libredfish header documents zero for non-integer input to integer getters; that zero
must not be mistaken for successful numeric coercion. The observed int-width overflow is
also not a prescription for native behavior. Payload string-node helpers wrap string nodes;
the raw whole-payload observation preserves the original value independently of the getter.
PercentComplete 101 and 2147483648 probe behavior outside the source-described 0–100 range;
acceptance by a generic reader does not validate the field. The large lane integer was
chosen to reveal float32 loss, not as a claim about a real PCIe configuration.

官方 int getter 对非整数返回零不等于完成字段转换；实测窄 int 溢出也不能作为 native
实现依据。字符串节点包装与原始整对象观测分开记录。两个超过 100 的进度值是边界探针，
被通用读取接受不证明字段有效；大 lane 整数用于揭示精度损失，不冒称真实硬件配置。

## Coverage boundary and recommendation / 覆盖边界与建议

The selected Redfishtool operation returns JSON; the selected libredfish APIs decode/query
payloads and expose primitive getters. This run did not execute GoFish-shaped PCIeInterface
or Task.PercentComplete validation/defaulting in either official reference. Consequently
it cannot decide string/bool/fraction acceptance, field-specific integer width, null/default
mapping, normative field ranges or automatic vendor workarounds. It does not cover all
other numeric properties, 32-bit Go, other Jansson versions, real firmware or security.

本次实际入口不提供或未执行 GoFish 同形的 PCIe/Task 校验与默认值规则，因此不裁决
字符串/布尔/小数接受、逐字段整数宽度、null/默认值、字段语义域或厂商修复；其他数值
属性、32 位 Go、其他 Jansson、实机与安全行为仍未覆盖。

Recommendation: retain the exact observed evidence; verify the applicable field domain
and comparable official behavior before promoting any candidate to a public exception.
Keep generic raw-value preservation separate from typed validation and language API
representation. Do not copy either GoFish float32 loss or libredfish's narrow-int cast
merely because it appears in a reference. Uncovered cases stay unresolved under the user's
rule, with normal functional work continuing against pinned GoFish.

建议继续区分原始值保留、类型化校验和语言 API 表示，补足字段语义域及可比较行为后再
判定例外。不因参考端存在精度损失或窄整数转换就直接照搬；未覆盖部分保留未决。

## Reproduce / 复现

Use clean source checkouts at the commits above. In this run `numeric_refs` was
`/tmp/moonredfish-official-numbers`; the build directories were outside the source trees.
Install Python dependencies into a venv, not the user's system environment. The report
records the resolved transitive versions for an exact rerun. The key local build commands:

```sh
numeric_refs=/tmp/moonredfish-official-numbers
cmake -S "$numeric_refs/jansson" -B "$numeric_refs/jansson-build" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$numeric_refs/deps" \
  -DJANSSON_BUILD_SHARED_LIBS=ON -DJANSSON_BUILD_DOCS=OFF \
  -DJANSSON_EXAMPLES=OFF -DJANSSON_WITHOUT_TESTS=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build "$numeric_refs/jansson-build" --parallel 4
cmake --install "$numeric_refs/jansson-build"
cmake -S "$numeric_refs/libredfish" -B "$numeric_refs/libredfish-build" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$numeric_refs/deps" \
  -DCMAKE_BUILD_RPATH="$numeric_refs/deps/lib" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  "-DCMAKE_SHARED_LINKER_FLAGS=-L$numeric_refs/deps/lib -L/opt/homebrew/opt/openssl@3/lib -lcrypto"
CPATH=/opt/homebrew/opt/openssl@3/include cmake --build "$numeric_refs/libredfish-build" --target redfish --parallel 4
python3 tools/test_official_numbers.py \
  --redfishtool "$numeric_refs/redfishtool" --libredfish "$numeric_refs/libredfish" \
  --jansson "$numeric_refs/jansson" --python "$numeric_refs/venv/bin/python" \
  --library "$numeric_refs/libredfish-build/lib/libredfish.dylib" --report /tmp/official-numbers.json
```

The harness creates its own loopback server and accepts no remote endpoint. It exercises
no session/login, device control, trust change or publication. Official numeric checks are
opt-in because the pinned external sources and native build are separate test dependencies.

入口不接受真实设备地址；不登录、不控制、不修改信任或发布。官方核验按需执行，其源码
和 native 构建依赖不加入 moonredfish 运行时。
