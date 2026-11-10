///|
/// Credentials are read from the caller's environment, never command-line arguments.
/// This example prints counts, not raw inventory, and logs out even after a read fails.
async fn main {
  let args = @env.args()
  guard args.length() == 2 else {
    fail("usage: session_inventory https://authorized-bmc.example.invalid")
  }
  guard @env.get_env_var("REDFISH_USERNAME") is Some(username) &&
    !username.is_empty() else {
    fail("REDFISH_USERNAME is required")
  }
  guard @env.get_env_var("REDFISH_PASSWORD") is Some(password) &&
    !password.is_empty() else {
    fail("REDFISH_PASSWORD is required")
  }
  let ca_file = @env.get_env_var("REDFISH_CA_FILE")
  let client = @moonredfish.Client::new(args[1], ca_file?)
  client.with_session(username, password, async fn(client) {
    let (systems, chassis, managers) = (
      client.systems(),
      client.chassis(),
      client.managers(),
    ) catch {
      @moonredfish.HttpStatus(status) =>
        fail("Redfish inventory request failed with HTTP \{status}")
      error => raise error
    }
    println(
      "inventory: systems=\{systems.length()}, chassis=\{chassis.length()}, managers=\{managers.length()}",
    )
  })
}
