# moonredfish

[简体中文](README.zh-CN.md)

**Release status:** Mooncakes currently provides 0.1.0. This README also describes
Unreleased APIs and examples available only in the GitHub checkout; installing 0.1.0
does not provide those additions. See [CHANGELOG.md](CHANGELOG.md). Subsequent registry
releases are published manually by the maintainer.

A small Redfish inventory client for **MoonBit native** applications. An independent,
personally maintained Apache-2.0 project, not a DMTF certification or a GoFish port.

The proposed full GoFish alignment is documented in the [draft parity plan](docs/GOFISH_PARITY.md).
Read-only differential work is underway; API/safety decisions remain open. See the
[39-case evidence and concrete decisions](docs/gofish/READONLY-01.md). Current subset
support is not complete GoFish equivalence. [Network configuration reads](docs/gofish/READONLY-02.md)
now include DHCPv4/DHCPv6, SLAAC, DNS and interface policies under the existing Field API.
[PCIe inventory](docs/gofish/READONLY-03.md) adds device/function reads and explicit topology
navigation. Open compatibility choices are in the [combined review](docs/gofish/DECISIONS.md).

## Scope

- Verified HTTPS using system roots or an application-managed CA file.
- ServiceRoot discovery, Systems, Chassis, Managers and arbitrary read-only GETs.
- Session creation/deletion, with tokens held only in an opaque client.
- Collection pagination, duplicate suppression, cycle detection and page limits.
- Per-request timeouts and bounded response bodies. No redirects or automatic retries.
- Original JSON retained for optional/OEM properties instead of a large generated schema.
- Unreleased typed System/Chassis/Manager summaries, Processor/Memory inventory, legacy
  Thermal/Power and modern Sensor/Fan/PowerSupply reads. Missing, null and zero stay distinct.

**Boundary:** inventory reads plus authentication lifecycle only. There are no APIs for
power reset, firmware updates, account changes, PATCH, or arbitrary POST/DELETE. No
Swordfish, subscriptions, task polling, Basic authentication, or vendor compatibility
claim. Tests use synthetic local HTTP/HTTPS services, not physical BMCs. Creating a
session changes server state, even though inventory operations are read-only.

## Typed hardware inventory (Unreleased)

Use `resource.system_info()`, `.chassis_info()` and `.manager_info()` for common
asset/health fields. `client.processors(system)`, `memory(system)`, `thermal(chassis)`,
`power(chassis)` and `sensors(chassis)` follow advertised links. Modern subsystem
readers expose Fans and PowerSupplies without guessing paths or swallowing 403/404.
All selected properties use `Field[T]` (`Missing`, `Null`, `Value`), retain original
JSON, and preserve unknown status strings. There is no full schema generation.

```mbt check
///|
test "typed hardware keeps zero distinct from unavailable" {
  let system = @moonredfish.parse_resource("/redfish/v1/Systems/demo", {
    "Model": null,
    "ProcessorSummary": { "Count": 0 },
  }).system_info()
  assert_true(system.model is Null)
  assert_true(system.serial_number is Missing)
  assert_eq(system.processor_count.value(), Some(0))
}
```

Run `moon run examples/hardware --target native` for a safe offline example, or
pass an authorized HTTPS endpoint for count-only inventory. Optional authentication
uses the same protected environment variables as `session_inventory`. See the
[typed inventory guide](docs/INVENTORY.md) for units, link semantics, modern-resource
limits and the runnable workflow. Raw inventory can contain private identifiers;
review and redact it before sharing.

## Extended inventory (Unreleased)

Storage/Drive/Volume, EthernetInterface/NetworkAdapter, LogService/LogEntry,
SoftwareInventory and current BIOS Attributes now have selected read-only views.
Explicit link methods retain three-state fields and per-operation traversal budgets.
There is no firmware update, BIOS write, log clearing or network control.
Run `moon run examples/extended --target native` for the safe offline example.
See the [extended inventory contract](docs/INVENTORY.md#extended-read-only-inventory-unreleased--扩展只读清单未发布)
for numeric bounds, API links, privacy and deliberate model limits.

## Install and examples

Requires native MoonBit and `moonbitlang/async` 0.22.1. The verified compiler is
`v0.10.20+65efd5b93` (`moon` 0.1.20261104). Networking/TLS uses the official async library.
Linux CI needs OpenSSL and zlib development packages; consult the
[async project](https://github.com/moonbitlang/async) for platform dependencies.

From a checkout, run the default example without any network access:

```sh
moon run examples/offline --target native
```

Install version 0.1.0 with `moon add pangbit/moonredfish@0.1.0`, then import
`pangbit/moonredfish` in the consuming package's `moon.pkg`.

```mbt check
///|
test "parse synthetic inventory" {
  let node = @moonredfish.parse_resource("/redfish/v1/Systems/demo", {
    "Id": "demo",
    "Name": "Synthetic server",
    "PowerState": "On",
  })
  assert_eq(node.string("PowerState"), Some("On"))
}
```

A native async application creates `Client::new("https://bmc.example.invalid")` and
calls `service_root()`, `systems()`, `chassis()`, `managers()`, `get(path)`, or `members(path)`.
A package with `async fn main` also imports `moonbitlang/async`. `members` returns URIs;
the inventory methods fetch the corresponding resources sequentially.

```sh
# Only with authorization for the target. This example performs anonymous HTTPS reads.
moon run examples/inventory --target native -- https://authorized-bmc.example.invalid
```

Authenticated applications can use `with_session(username, password, body)` for a
scoped session: it returns the body's result only after attempting logout on normal
return, error or cancellation. Cleanup is cancellation-protected but still bounded by
`timeout_ms`. If body and cleanup both fail, the cleanup error takes precedence; failed
logout keeps the local session for an explicit retry. Never change session state or
share the client concurrently inside the body. Overlapping login/logout calls are
rejected with `SessionBusy`, instead of issuing duplicate lifecycle requests.

For manual control, call `login(username, password)` before reads and `logout()`
afterward, including your own error/cancellation cleanup path. There is no background
re-login or automatic logout in the basic login/logout methods. Login reads
ServiceRoot `Links.Sessions` without traversing SessionService. If that link is absent,
or root access returns 401/403, it uses `/redfish/v1/SessionService/Sessions`. An unsafe
or malformed advertised link is rejected, not silently replaced. The resulting session
Location must be one direct child of the selected collection. Discovery accepts only
paths ending in `/Sessions` (optionally followed by `/`), so a mistaken link to Systems
or another non-session collection cannot redirect login or logout there. This is a
deliberate compatibility restriction; unconventional collection names are rejected. Serialize login/logout on each client,
and do not overlap lifecycle changes with other requests on the same client. A failed
or cancelled login may already have created a remote session. Do not automatically retry
it; inspect session state through authorized management tooling.

The current checkout also provides `examples/session_inventory` (not included in the
published 0.1.0 example set). It reads `REDFISH_USERNAME`, `REDFISH_PASSWORD` and optional
`REDFISH_CA_FILE` from the application environment, performs HTTPS inventory reads,
prints counts only, and uses `with_session` to attempt logout on success, failure or cancellation. The cleanup
request still has a timeout and can fail. A logout failure makes the example fail rather
than claiming cleanup succeeded. Environment variables avoid command-line arguments,
but are not a secret vault: protect the launching process and never commit a `.env` file.

```sh
# Supply the environment through your trusted launcher. Do not paste passwords here.
moon run examples/session_inventory --target native -- https://authorized-bmc.example.invalid
```

The mock runner below tests this actual executable with synthetic credentials and a
local TLS server, including logout after a failed inventory request. No device access
is needed to review the authenticated workflow.

## Safety and limits

- Construction performs no I/O. HTTPS is required except for explicitly enabled loopback
  HTTP mocks (`allow_loopback_http=true`). TLS verification cannot be disabled.
  `ca_file=...` trusts a specific application-managed PEM CA file.
- Followed links must be origin-relative `/redfish/v1` paths. Absolute links, encoded
  path segments, traversal, fragments, backslashes and controls are rejected. Query
  strings may contain percent escapes. This safety-first subset can reject otherwise
  valid vendor URIs.
- Defaults: 10-second per-request timeout, 4 MiB per response body, 100 collection pages.
  Each request closes its connection. No connection pool or cache is maintained.
  `members`, `systems`, `chassis` and `managers` additionally share a per-operation
  60-second deadline (`operation_timeout_ms`), a 10,000-unique-member limit
  (`max_members`), and a 16 MiB aggregate response-body budget
  (`max_total_response_bytes`). These are transfer budgets, not exact heap-size limits.
  Limits raise `OperationTimeout`, `MemberLimit` or `TotalResponseTooLarge`, with no
  partial result returned. Inventory budgets include root discovery, every collection
  page and all member GETs. Each call has its own budget. A paged collection is not a
  snapshot: changes on the service can still cause omissions; nextLink queries remain
  opaque and duplicate suppression does not guarantee snapshot consistency.
- Non-2xx GET responses produce `HttpStatus(status)` without echoing response bodies.
  Enable `detailed_errors=true` to receive `DetailedHttpStatus(info)` with status,
  the standard `error.code`, and at most 16 distinct ExtendedInfo `MessageId` values.
  Identifiers are limited to 256 ASCII identifier characters; free-form messages,
  arguments, resolutions, headers and bodies are not retained. These identifiers are
  still server-provided data, not safe-to-publish guarantees. The default `HttpStatus`
  behavior is unchanged. This is not a full message-registry decoder.
  JSON must be valid UTF-8 without duplicate keys. Transport/TLS errors remain
  async-library errors.
- Missing properties remain optional. Raw `Resource.json` may contain private inventory;
  redact it before logging or sharing. Never commit credentials, tokens, private hosts,
  actual hardware identifiers or raw captures.

## Verification

```sh
moon update
moon check --target native --deny-warn
moon test --target native --deny-warn
moon run examples/offline --target native
python3 tools/test_mock.py
moon info --target native
moon fmt --check
moon package --list
```

The integration script needs Python 3 and OpenSSL. It starts loopback servers on dynamic
ports, generates a temporary certificate, and verifies session lifecycle, discovery,
pagination/deduplication, unsafe-link and redirect rejection, malformed JSON, HTTP errors,
body/page/time limits, untrusted certificate and hostname-mismatch rejection, and
successful custom-CA HTTPS. It also checks the authenticated example's success/error
cleanup and verifies that its output excludes credentials, tokens and response bodies.
All data in this runner is synthetic. It never uses a real BMC or external test service. Launch it via
Python rather than directly running `examples/integration`.

CI is configured for Linux x86_64 and macOS arm64. A workflow file is not evidence that
remote CI passed. Device interoperability, other platforms, and full Redfish conformance
remain unverified until separately tested.

## References and design

- [DMTF Redfish](https://www.dmtf.org/standards/redfish): protocol reference.
- [GoFish](https://github.com/stmcginnis/gofish), BSD-3-Clause: comparison project, a mature
  Go client covering Redfish/Swordfish, many typed resources, and actions. moonredfish
  takes inspiration from its client/discovery/inventory usage, not its source, branding,
  coverage or compatibility claims. It is not API-compatible with GoFish.
- [moonbitlang/async](https://github.com/moonbitlang/async), Apache-2.0: HTTP, networking,
  TLS, cancellation and timeouts. These layers are reused rather than reimplemented.

The current release boundary is read-only inventory. The full GoFish target includes all
public typed capabilities; raw JSON does not close missing APIs. Implementation proceeds
in reviewable batches under the parity plan.

For an independent shape check, run `python3 tools/test_reference.py`. It downloads
seven SHA-256-pinned public DMTF mockup files and serves them on loopback. It is an
optional networked check locally. Linux CI checks these same inputs through the GoFish
comparison below. Scope and copyright attribution
are documented in [docs/REFERENCE.md](docs/REFERENCE.md); it is not real-device testing.

For a small side-by-side check, run `python3 tools/test_gofish.py` with Go 1.21+ installed
(verified with Go 1.24.0). It compares selected inventory fields against GoFish v0.27.0
and the pinned source data, then checks shared pagination, error, session and TLS behavior
on a synthetic loopback service. GoFish is a test-only dependency, not part of the MoonBit
library. Run `python3 tools/test_extended.py` for the storage, network, logs, firmware
and BIOS comparison. Linux CI runs both commands. See [docs/COMPARISON.md](docs/COMPARISON.md) for
the result, intentional differences and limitations.

For a concise reproducible review, see [docs/ACCEPTANCE.md](docs/ACCEPTANCE.md).

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) and [LICENSE](LICENSE).
