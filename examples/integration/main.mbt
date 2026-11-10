///|
async fn main {
  let args = @env.args()
  guard args.length() == 5 else { fail("run via python3 tools/test_mock.py") }
  let endpoint = args[1]
  let c = @moonredfish.Client::new(endpoint, allow_loopback_http=true)
  let wrong_password = try {
    c.login("synthetic-user", "synthetic-wrong")
    false
  } catch {
    @moonredfish.HttpStatus(401) => true
    _ => false
  }
  assert_true(wrong_password)
  c.login("synthetic-user", "synthetic-password")
  let systems = c.systems()
  assert_eq(systems.length(), 2)
  assert_eq(systems[0].id, Some("1"))
  assert_eq(systems[1].id, Some("2"))
  assert_eq(c.chassis().length(), 1)
  assert_eq(c.managers().length(), 1)
  let already = try {
    c.login("synthetic-user", "synthetic-password")
    false
  } catch {
    @moonredfish.SessionAlreadyActive => true
    _ => false
  }
  assert_true(already)
  let forbidden = try {
    ignore(c.get("/redfish/v1/Forbidden"))
    false
  } catch {
    @moonredfish.HttpStatus(403) => true
    _ => false
  }
  assert_true(forbidden)
  let diagnostic_client = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    detailed_errors=true,
  )
  let diagnostic = try {
    ignore(diagnostic_client.get("/redfish/v1/Forbidden"))
    false
  } catch {
    @moonredfish.DetailedHttpStatus(info) => {
      assert_eq(info.status, 403)
      assert_eq(info.code, Some("Base.1.0.GeneralError"))
      assert_eq(info.message_ids, ["Base.1.0.InsufficientPrivilege"])
      true
    }
    _ => false
  }
  assert_true(diagnostic)
  let redirect = try {
    ignore(c.get("/redfish/v1/Redirect"))
    false
  } catch {
    @moonredfish.HttpStatus(302) => true
    _ => false
  }
  assert_true(redirect)
  let invalid = try {
    ignore(c.get("/redfish/v1/Invalid"))
    false
  } catch {
    @moonredfish.InvalidResponse(_) => true
    _ => false
  }
  assert_true(invalid)
  let cycle = try {
    ignore(c.members("/redfish/v1/Cycle"))
    false
  } catch {
    @moonredfish.PaginationCycle => true
    _ => false
  }
  assert_true(cycle)
  let unsafe_link = try {
    ignore(c.members("/redfish/v1/Unsafe"))
    false
  } catch {
    @moonredfish.InvalidPath => true
    _ => false
  }
  assert_true(unsafe_link)
  let limited = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    max_pages=1,
  )
  let pages = try {
    ignore(limited.members("/redfish/v1/Systems"))
    false
  } catch {
    @moonredfish.PageLimit => true
    _ => false
  }
  assert_true(pages)
  let member_limited = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    max_members=1,
  )
  let member_limit = try {
    ignore(member_limited.members("/redfish/v1/Systems"))
    false
  } catch {
    @moonredfish.MemberLimit => true
    _ => false
  }
  assert_true(member_limit)
  let byte_limited = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    max_total_response_bytes=150,
  )
  let byte_limit = try {
    ignore(byte_limited.members("/redfish/v1/Systems"))
    false
  } catch {
    @moonredfish.TotalResponseTooLarge => true
    _ => false
  }
  assert_true(byte_limit)
  ignore(byte_limited.get("/redfish/v1/Systems"))
  let operation_limited = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    timeout_ms=1000,
    operation_timeout_ms=100,
  )
  let operation_timeout = try {
    ignore(operation_limited.members("/redfish/v1/SlowPages?page=1"))
    false
  } catch {
    @moonredfish.OperationTimeout => true
    _ => false
  }
  assert_true(operation_timeout)
  let bounded = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    max_response_bytes=16,
  )
  let large = try {
    ignore(bounded.service_root())
    false
  } catch {
    @moonredfish.ResponseTooLarge => true
    _ => false
  }
  assert_true(large)
  let quick = @moonredfish.Client::new(
    endpoint,
    allow_loopback_http=true,
    timeout_ms=30,
  )
  let timeout = try {
    ignore(quick.get("/redfish/v1/Slow"))
    false
  } catch {
    @async.TimeoutError => true
    _ => false
  }
  assert_true(timeout)
  c.logout()
  let logged_out = try {
    c.logout()
    false
  } catch {
    @moonredfish.NoSession => true
    _ => false
  }
  assert_true(logged_out)
  let untrusted = @moonredfish.Client::new(args[2])
  let rejected = try {
    ignore(untrusted.service_root())
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let trusted = @moonredfish.Client::new(args[2], ca_file=args[3])
  ignore(trusted.service_root())
  let wrong_hostname = @moonredfish.Client::new(args[4], ca_file=args[3])
  let hostname_rejected = try {
    ignore(wrong_hostname.service_root())
    false
  } catch {
    @tls.TlsError(_) => true
    _ => false
  }
  assert_true(hostname_rejected)
  println("mock integration: HTTP, session, pagination, limits, and TLS passed")
}
