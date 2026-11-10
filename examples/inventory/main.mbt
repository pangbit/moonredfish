///|
/// Anonymous HTTPS inventory. Session credentials belong in application-managed
/// secret storage, never command-line arguments, committed files, or logs.
async fn main {
  let args = @env.args()
  guard args.length() == 2 else {
    fail("usage: inventory https://authorized-bmc.example.invalid")
  }
  let client = @moonredfish.Client::new(args[1])
  for system in client.systems() {
    println(
      "\{system.id.unwrap_or("unknown")}: \{system.name.unwrap_or("unnamed")}",
    )
  }
}
