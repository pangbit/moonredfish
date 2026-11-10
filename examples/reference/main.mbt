///|
/// Run only through tools/test_reference.py, which serves pinned public mockups.
async fn main {
  let args = @env.args()
  guard args.length() == 2 else {
    fail("run via python3 tools/test_reference.py")
  }
  let client = @moonredfish.Client::new(args[1], allow_loopback_http=true)
  assert_eq(client.service_root().id, Some("RootService"))
  let systems = client.systems()
  let chassis = client.chassis()
  let managers = client.managers()
  assert_eq(systems.length(), 1)
  assert_eq(chassis.length(), 1)
  assert_eq(managers.length(), 1)
  assert_eq(systems[0].id, Some("437XR1138R2"))
  assert_eq(chassis[0].id, Some("1U"))
  assert_eq(managers[0].id, Some("BMC"))
  assert_true(systems[0].resource_type is Some(_))
  assert_true(chassis[0].resource_type is Some(_))
  assert_true(managers[0].resource_type is Some(_))
  println("pinned DMTF mockups: root and three inventory collections passed")
}
