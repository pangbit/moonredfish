///|
/// ServiceRoot Links.Sessions is available without traversing SessionService.
/// Missing discovery is different from a malformed or unsafe advertised target.
fn session_collection_link(root : Json) -> String? raise RedfishError {
  guard root is Object(fields) else {
    raise InvalidResponse("expected service root object")
  }
  match fields.get("Links") {
    None | Some(Null) => None
    Some(Object(links)) =>
      match links.get("Sessions") {
        None | Some(Null) => None
        Some(value) => {
          let uri = link_uri(value)
          if uri.contains("?") {
            raise InvalidResponse("session collection query unsupported")
          }
          if !uri.has_suffix("/Sessions") && !uri.has_suffix("/Sessions/") {
            raise InvalidResponse("expected an explicit Sessions collection")
          }
          Some(uri)
        }
      }
    _ => raise InvalidResponse("expected service root Links object")
  }
}

///|
async fn Client::discover_session_collection(self : Client) -> String {
  let fallback = "/redfish/v1/SessionService/Sessions"
  let (response, data) = self.request(Get, "/redfish/v1/")
  if response.code == 401 || response.code == 403 {
    return fallback
  }
  if response.code < 200 || response.code >= 300 {
    self.raise_http_status(response.code, data)
  }
  session_collection_link(decode_json(data)).unwrap_or(fallback)
}

///|
/// Log in, run one body, then attempt logout even on error or cancellation.
/// Cleanup is cancellation-protected but still request-timeout-bounded. If both
/// body and cleanup fail, the cleanup error takes precedence. A failed logout
/// retains local session state so the caller can explicitly retry `logout`.
/// Do not change sessions or concurrently share this client inside the body.
/// An ambiguous login failure cannot be cleaned up without a validated Location.
pub async fn[T] Client::with_session(
  self : Client,
  username : String,
  password : String,
  body : async (Client) -> T,
) -> T {
  self.login(username, password)
  defer @async.protect_from_cancel(async fn() { self.logout() })
  body(self)
}
