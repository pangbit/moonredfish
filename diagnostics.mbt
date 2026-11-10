///|
/// Opt-in, bounded machine-readable diagnostics. No free-form Message,
/// MessageArgs, Resolution, headers, request URI, or raw body is retained.
/// Identifiers still originate from an untrusted server; do not log them blindly.
#derive(@debug.Debug)
pub struct HttpDiagnostic {
  status : Int32
  code : String?
  message_ids : Array[String]
}

///|
pub extend HttpDiagnostic with @debug.Debug::{to_repr}

///|
fn diagnostic_identifier(value : String?) -> String? {
  guard value is Some(value) && !value.is_empty() && value.length() <= 256 else {
    return None
  }
  for c in value {
    if !((c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '.' ||
      c == '_' ||
      c == '-') {
      return None
    }
  }
  Some(value)
}

///|
fn http_diagnostic(status : Int32, data : Bytes) -> HttpDiagnostic {
  let empty = { status, code: None, message_ids: [], }
  let value = decode_json(data) catch { _ => return empty }
  guard value is Object(root) && root.get("error") is Some(Object(error)) else {
    return empty
  }
  let code = diagnostic_identifier(
    match error.get("code") {
      Some(String(value)) => Some(value)
      _ => None
    },
  )
  let message_ids = []
  if error.get("@Message.ExtendedInfo") is Some(Array(messages)) {
    for message in messages {
      if message_ids.length() >= 16 {
        break
      }
      if diagnostic_identifier(optional_string(message, "MessageId"))
        is Some(id) &&
        !message_ids.contains(id) {
        message_ids.push(id)
      }
    }
  }
  { status, code, message_ids, }
}

///|
fn Client::raise_http_status(
  self : Client,
  status : Int32,
  data : Bytes,
) -> Unit raise RedfishError {
  if self.detailed_errors {
    raise DetailedHttpStatus(http_diagnostic(status, data))
  }
  raise HttpStatus(status)
}
