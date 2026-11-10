# moonredfish

[简体中文](README.zh-CN.md)

A small Redfish inventory client for **MoonBit native** applications. An independent,
personally maintained Apache-2.0 project, not a DMTF certification or a GoFish port.

## Scope

- Verified HTTPS using system roots or an application-managed CA file.
- ServiceRoot discovery, Systems, Chassis, Managers and arbitrary read-only GETs.
- Session creation/deletion, with tokens held only in an opaque client.
- Collection pagination, duplicate suppression, cycle detection and page limits.
- Per-request timeouts and bounded response bodies. No redirects or automatic retries.
- Original JSON retained for optional/OEM properties instead of a large generated schema.

**Boundary:** inventory reads plus authentication lifecycle only. There are no APIs for
power reset, firmware updates, account changes, PATCH, or arbitrary POST/DELETE. No
Swordfish, subscriptions, task polling, Basic authentication, or vendor compatibility
claim. Tests use synthetic local HTTP/HTTPS services, not physical BMCs. Creating a
session changes server state, even though inventory operations are read-only.

## Install and examples

Requires native MoonBit and `moonbitlang/async` 0.22.1. The verified compiler is
`v0.10.20+65efd5b93` (`moon` 0.1.20261104). Networking/TLS uses the official async library.
Linux CI needs OpenSSL and zlib development packages; consult the
[async project](https://github.com/moonbitlang/async) for platform dependencies.

From a checkout, run the default example without any network access:

```sh
moon run examples/offline --target native
```

After a registry release is available, use `moon add pangbit/moonredfish`. Until then,
use a local MoonBit workspace dependency. Import `pangbit/moonredfish` in `moon.pkg`.

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

Authenticated applications call `login(username, password)` before reads and `logout()`
afterward, including their own error/cancellation cleanup path. There is no background
re-login or automatic logout. Login uses `/redfish/v1/SessionService/Sessions`; other
session URI conventions are not supported yet. Serialize login/logout on each client,
and do not overlap lifecycle changes with other requests on the same client. A failed
or cancelled login may already have created a remote session. Do not automatically retry
it; inspect session state through authorized management tooling.

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
- Non-2xx GET responses produce `HttpStatus(status)` without echoing response bodies.
  JSON must be valid UTF-8 without duplicate keys. No full Redfish error-message registry
  decoder is provided. Transport/TLS errors remain async-library errors.
- Missing properties remain optional. Raw `Resource.json` may contain private inventory;
  redact it before logging or sharing. Never commit credentials, tokens, private hosts,
  actual hardware identifiers or raw captures.

## Verification

```sh
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
body/page/time limits, untrusted certificate rejection and successful custom-CA HTTPS.
All data is synthetic. It never uses a real BMC or external test service. Launch it via
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

The smallest useful boundary is safely retrieving inventory. Preserving JSON makes the
project maintainable by one person without generating thousands of schema types. Add
typed helpers only when a concrete, tested use case requires them.

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) and [LICENSE](LICENSE).
