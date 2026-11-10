///|
/// Errors never retain raw response bodies or free-form server messages.
/// Opt-in diagnostic identifiers remain untrusted server data.
#derive(@debug.Debug)
pub suberror RedfishError {
  InvalidEndpoint
  InvalidPath
  InvalidOptions
  InvalidResponse(String)
  HttpStatus(Int32)
  DetailedHttpStatus(HttpDiagnostic)
  ResponseTooLarge
  PageLimit
  PaginationCycle
  MemberLimit
  TotalResponseTooLarge
  OperationTimeout
  SessionAlreadyActive
  SessionBusy
  NoSession
}

///|
/// A resource keeps its original JSON for optional and OEM fields.
pub struct Resource {
  uri : String
  id : String?
  name : String?
  resource_type : String?
  json : Json
}

///|
/// One collection page. Use `Client::members` for bounded pagination.
pub struct Collection {
  members : Array[String]
  next_link : String?
}

///|
/// Reads an optional string property without inventing a default value.
pub fn Resource::string(self : Resource, key : String) -> String? {
  optional_string(self.json, key)
}

///|
/// Reads a resource link and rejects targets outside the Redfish root.
pub fn Resource::link(
  self : Resource,
  key : String,
) -> String? raise RedfishError {
  match self.json {
    Object(fields) =>
      match fields.get(key) {
        None | Some(Null) => None
        Some(value) => Some(link_uri(value))
      }
    _ => None
  }
}

///|
fn optional_string(value : Json, key : String) -> String? {
  match value {
    Object(fields) =>
      match fields.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
fn link_uri(value : Json) -> String raise RedfishError {
  guard optional_string(value, "@odata.id") is Some(uri) else {
    raise InvalidResponse("missing @odata.id link")
  }
  validate_path(uri)
  uri
}

///|
/// Parses an object without requiring schema-version-specific optional fields.
pub fn parse_resource(
  uri : String,
  value : Json,
) -> Resource raise RedfishError {
  validate_path(uri)
  guard value is Object(_) else {
    raise InvalidResponse("expected resource object")
  }
  {
    uri,
    id: optional_string(value, "Id"),
    name: optional_string(value, "Name"),
    resource_type: optional_string(value, "@odata.type"),
    json: value,
  }
}

///|
/// Parses collection links. Null or malformed Members is an error, not empty data.
pub fn parse_collection(value : Json) -> Collection raise RedfishError {
  guard value is Object(fields) else {
    raise InvalidResponse("expected collection object")
  }
  guard fields.get("Members") is Some(Array(members)) else {
    raise InvalidResponse("expected Members array")
  }
  let links = members.map(link_uri)
  let next_link = match fields.get("Members@odata.nextLink") {
    None | Some(Null) => None
    Some(String(s)) => {
      validate_path(s)
      Some(s)
    }
    _ => raise InvalidResponse("expected nextLink string")
  }
  { members: links, next_link, }
}

///|
/// Accepts only origin-relative Redfish paths. Encoded path segments, traversal,
/// fragments and controls are rejected. Query strings may contain percent escapes.
fn validate_path(path : String) -> Unit raise RedfishError {
  for c in path {
    if c <= ' ' || c == '\\' || c == '#' || c == '\u{7f}' {
      raise InvalidPath
    }
  }
  let raw = path.split("?").to_array()[0].to_owned()
  if !(raw == "/redfish/v1" || raw.has_prefix("/redfish/v1/")) ||
    raw.contains("%") ||
    raw.contains("//") {
    raise InvalidPath
  }
  for part in raw.split("/") {
    if part == "." || part == ".." {
      raise InvalidPath
    }
  }
}

///|
fn validate_endpoint(
  endpoint : String,
  allow_loopback_http : Bool,
) -> Unit raise RedfishError {
  let secure = endpoint.has_prefix("https://")
  let host = if secure {
    endpoint[8:].to_owned()
  } else if allow_loopback_http && endpoint.has_prefix("http://") {
    endpoint[7:].to_owned()
  } else {
    raise InvalidEndpoint
  }
  guard !host.is_empty() else { raise InvalidEndpoint }
  for c in host {
    if c <= ' ' ||
      c == '/' ||
      c == '\\' ||
      c == '@' ||
      c == '?' ||
      c == '#' ||
      c == '%' ||
      c == '\u{7f}' {
      raise InvalidEndpoint
    }
  }
  if !secure {
    let hostname = if host.has_prefix("[::1]") {
      "[::1]"
    } else {
      host.split(":").to_array()[0].to_owned()
    }
    if hostname != "127.0.0.1" && hostname != "localhost" && hostname != "[::1]" {
      raise InvalidEndpoint
    }
    if hostname == "[::1]" && host != "[::1]" && !host.has_prefix("[::1]:") {
      raise InvalidEndpoint
    }
  }
}

///|
/// Native client. HTTP is permitted only for explicitly enabled loopback mocks.
/// Not safe for concurrent login/logout; serialize session lifecycle operations.
/// Each request opens a bounded, timeout-protected connection and never redirects.
struct Client {
  endpoint : String
  timeout_ms : Int32
  max_response_bytes : Int32
  max_pages : Int32
  detailed_errors : Bool
  max_members : Int32
  max_total_response_bytes : Int32
  operation_timeout_ms : Int32
  trust : @tls.TrustedRoot
  mut token : String?
  mut session_uri : String?
  mut session_changing : Bool
}

///|
/// No connection is made until a method is called. TLS verification cannot be disabled.
pub fn Client::new(
  endpoint : String,
  ca_file? : String,
  allow_loopback_http~ : Bool = false,
  timeout_ms~ : Int32 = 10000,
  max_response_bytes~ : Int32 = 4194304,
  max_pages~ : Int32 = 100,
  detailed_errors~ : Bool = false,
  max_members~ : Int32 = 10000,
  max_total_response_bytes~ : Int32 = 16777216,
  operation_timeout_ms~ : Int32 = 60000,
) -> Client raise RedfishError {
  validate_endpoint(endpoint, allow_loopback_http)
  if timeout_ms <= 0 ||
    max_response_bytes <= 0 ||
    max_response_bytes > 67108864 ||
    max_pages <= 0 ||
    max_pages > 10000 ||
    max_members <= 0 ||
    max_members > 100000 ||
    max_total_response_bytes <= 0 ||
    max_total_response_bytes > 268435456 ||
    operation_timeout_ms <= 0 {
    raise InvalidOptions
  }
  {
    endpoint,
    timeout_ms,
    max_response_bytes,
    max_pages,
    detailed_errors,
    max_members,
    max_total_response_bytes,
    operation_timeout_ms,
    trust: match ca_file {
      Some(path) => @tls.CustomPemFile(path)
      None => @tls.SystemRoot
    },
    token: None,
    session_uri: None,
    session_changing: false,
  }
}

///|
async fn Client::request(
  self : Client,
  meth : @http.RequestMethod,
  path : String,
  body? : Json,
  budget? : ReadBudget,
) -> (@http.Response, Bytes) {
  validate_path(path)
  @async.with_timeout(self.timeout_ms, async fn() {
    let headers : @http.Headers = {
      "Accept": "application/json",
      "OData-Version": "4.0",
      "User-Agent": "moonredfish/0.1",
      "Accept-Encoding": "identity",
    }
    if self.token is Some(token) {
      headers["X-Auth-Token"] = token
    }
    let conn = @http.Client(self.endpoint, headers~, trust=self.trust)
    defer conn.close()
    let response = if body is Some(body) {
      conn.request(meth, path, extra_headers={
        "Content-Type": "application/json",
      })
      conn.write(body)
      conn.end_request()
    } else {
      conn.request(meth, path)
      conn.end_request()
    }
    let data = @buffer.Buffer()
    while conn.read_some(max_len=8192) is Some(chunk) {
      if chunk.length() > self.max_response_bytes - data.length() {
        raise ResponseTooLarge
      }
      if budget is Some(budget) {
        if chunk.length() > budget.remaining {
          raise TotalResponseTooLarge
        }
        budget.remaining -= chunk.length()
      }
      data.write_bytes(chunk)
    }
    (response, data.to_bytes())
  })
}

///|
fn decode_json(data : Bytes) -> Json raise RedfishError {
  @json.parse(@utf8.decode(data), reject_duplicate_keys=true) catch {
    _ => raise InvalidResponse("invalid UTF-8 or JSON")
  }
}

///|
/// GET only; non-2xx responses (including redirects) produce HttpStatus, or
/// DetailedHttpStatus when detailed_errors is explicitly enabled.
pub async fn Client::get(self : Client, path : String) -> Resource {
  self.read_resource(path)
}

///|
async fn Client::read_resource(
  self : Client,
  path : String,
  budget? : ReadBudget,
) -> Resource {
  let (response, data) = self.request(Get, path, budget?)
  if response.code < 200 || response.code >= 300 {
    self.raise_http_status(response.code, data)
  }
  parse_resource(path, decode_json(data))
}

///|
pub async fn Client::service_root(self : Client) -> Resource {
  self.get("/redfish/v1/")
}

///|
/// Traverses collection pages with a cycle guard and a page limit.
/// No resource GETs are performed; duplicate links are returned only once.
pub async fn Client::members(self : Client, path : String) -> Array[String] {
  let budget = ReadBudget::{ remaining: self.max_total_response_bytes, }
  @async.with_timeout(
    self.operation_timeout_ms,
    async fn() { self.read_members(path, budget) },
    error=OperationTimeout,
  )
}

///|
async fn Client::read_members(
  self : Client,
  path : String,
  budget : ReadBudget,
) -> Array[String] {
  let visited : Map[String, Bool] = Map([])
  let seen : Map[String, Bool] = Map([])
  let result = []
  let mut next = Some(path)
  while next is Some(uri) {
    if visited.contains(uri) {
      raise PaginationCycle
    }
    if visited.length() >= self.max_pages {
      raise PageLimit
    }
    visited[uri] = true
    let page = parse_collection(self.read_resource(uri, budget~).json)
    for item in page.members {
      if !seen.contains(item) {
        if result.length() >= self.max_members {
          raise MemberLimit
        }
        seen[item] = true
        result.push(item)
      }
    }
    next = page.next_link
  }
  result
}

///|
async fn Client::inventory(self : Client, kind : String) -> Array[Resource] {
  let budget = ReadBudget::{ remaining: self.max_total_response_bytes, }
  @async.with_timeout(
    self.operation_timeout_ms,
    async fn() {
      let root = self.read_resource("/redfish/v1/", budget~)
      guard root.link(kind) is Some(path) else {
        raise InvalidResponse("service root link unavailable")
      }
      let result = []
      for uri in self.read_members(path, budget) {
        result.push(self.read_resource(uri, budget~))
      }
      result
    },
    error=OperationTimeout,
  )
}

///|
pub async fn Client::systems(self : Client) -> Array[Resource] {
  self.inventory("Systems")
}

///|
pub async fn Client::chassis(self : Client) -> Array[Resource] {
  self.inventory("Chassis")
}

///|
pub async fn Client::managers(self : Client) -> Array[Resource] {
  self.inventory("Managers")
}

///|
/// Creates one Redfish session. This is the only POST API. The token is held only
/// in memory; credentials are not stored. No retries are made for ambiguous POSTs.
/// Discovers the session collection from ServiceRoot Links.Sessions, using the
/// standard endpoint only if absent or root access returns 401/403.
pub async fn Client::login(
  self : Client,
  username : String,
  password : String,
) -> Unit {
  if self.session_changing {
    raise SessionBusy
  }
  if self.token is Some(_) {
    raise SessionAlreadyActive
  }
  self.session_changing = true
  defer {
    self.session_changing = false
  }
  let collection = self.discover_session_collection()
  let (response, data) = self.request(Post, collection, body={
    "UserName": username,
    "Password": password,
  })
  if response.code != 201 {
    self.raise_http_status(response.code, data)
  }
  guard response.headers.get("X-Auth-Token") is Some(token) && !token.is_empty() else {
    raise InvalidResponse("session token unavailable")
  }
  for c in token {
    if c <= ' ' || c >= '\u{7f}' {
      raise InvalidResponse("invalid session token")
    }
  }
  guard response.headers.get("Location") is Some(uri) else {
    raise InvalidResponse("session location unavailable")
  }
  validate_session_location(uri, collection~)
  self.token = Some(token)
  self.session_uri = Some(uri)
}

///|
/// Deletes only this client's session. On transport failure it remains active
/// locally, allowing the caller to retry logout. A 401/404 means it already expired.
pub async fn Client::logout(self : Client) -> Unit {
  if self.session_changing {
    raise SessionBusy
  }
  guard self.session_uri is Some(path) else { raise NoSession }
  self.session_changing = true
  defer {
    self.session_changing = false
  }
  let (response, data) = self.request(Delete, path)
  if response.code != 200 &&
    response.code != 204 &&
    response.code != 401 &&
    response.code != 404 {
    self.raise_http_status(response.code, data)
  }
  self.token = None
  self.session_uri = None
}

///|
pub extend RedfishError with @debug.Debug::{to_repr}

///|
fn validate_session_location(
  uri : String,
  collection~ : String = "/redfish/v1/SessionService/Sessions",
) -> Unit raise RedfishError {
  validate_path(uri)
  let prefix = if collection.has_suffix("/") {
    collection
  } else {
    collection + "/"
  }
  if !uri.has_prefix(prefix) || uri.contains("?") {
    raise InvalidResponse("unexpected session location")
  }
  let suffix = uri[prefix.length():]
  if suffix.is_empty() || suffix.contains("/") {
    raise InvalidResponse("expected one session member")
  }
}

///|
priv struct ReadBudget {
  mut remaining : Int32
}
