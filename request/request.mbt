///|
pub(all) enum RequestError {
  Http(@http.ErrorCode)
  InvalidUrl(String)
  InvalidHeader(String)
  Io(String)
  InvalidJson(String)
  TooManyRedirects
}

///|
/// HTTP methods exposed without leaking the generated WASI bindings.
pub(all) enum Method {
  Get
  Head
  Post
  Put
  Delete
  Connect
  Options
  Trace
  Patch
  Other(String)
}

///|
fn Method::to_wasi(self : Method) -> @http.Method {
  match self {
    Get => @http.Method::Get
    Head => @http.Method::Head
    Post => @http.Method::Post
    Put => @http.Method::Put
    Delete => @http.Method::Delete
    Connect => @http.Method::Connect
    Options => @http.Method::Options
    Trace => @http.Method::Trace
    Patch => @http.Method::Patch
    Other(value) => @http.Method::Other(value)
  }
}

///|
pub fn RequestError::message(self : RequestError) -> String {
  match self {
    Http(_) => "HTTP transport error"
    InvalidUrl(message) => message
    InvalidHeader(message) => message
    Io(message) => message
    InvalidJson(message) => message
    TooManyRedirects => "too many HTTP redirects"
  }
}

///|
pub(all) struct Response {
  status_code : UInt32
  headers : Array[(String, Bytes)]
  body : Bytes
}

///|
pub fn Response::header(self : Response, name : String) -> String? {
  let normalized = name.to_lower()
  for header in self.headers {
    if header.0.to_lower() == normalized {
      return Some(@utf8.decode_lossy(header.1))
    }
  }
  None
}

///|
pub fn Response::as_string(self : Response) -> Result[String, RequestError] {
  Ok(@utf8.decode(self.body)) catch {
    _ => Err(InvalidJson("response body is not valid UTF-8"))
  }
}

///|
pub fn Response::json(self : Response) -> Result[Json, RequestError] {
  let text = match self.as_string() {
    Ok(text) => text
    Err(error) => return Err(error)
  }
  Ok(@json.parse(text)) catch {
    _ => Err(InvalidJson("response body is not valid JSON"))
  }
}

///|
pub struct Request {
  method_ : Method
  url : String
  headers : Array[(String, String)]
  mut body : Bytes?
  mut follow_redirects : Bool
}

///|
pub fn Request::new(method_ : Method, url : String) -> Request {
  { method_, url, headers: [], body: None, follow_redirects: true, }
}

///|
pub fn Request::header(
  self : Request,
  name : String,
  value : String,
) -> Result[Request, RequestError] {
  if name.is_empty() {
    return Err(InvalidHeader("header name cannot be empty"))
  }
  self.headers.push((name, value))
  Ok(self)
}

///|
pub fn Request::body(self : Request, body : Bytes) -> Request {
  self.body = Some(body)
  self
}

///|
pub fn Request::with_json(self : Request, value : Json) -> Request {
  self.headers.push(("Content-Type", "application/json; charset=UTF-8"))
  self.body(@utf8.encode(value.stringify()))
}

///|
pub fn Request::follow_redirects(self : Request, enabled : Bool) -> Request {
  self.follow_redirects = enabled
  self
}

///|
pub fn Request::send(self : Request) -> Result[Response, RequestError] {
  let mut url = self.url
  for redirects = 0; redirects < 6; redirects = redirects + 1 {
    let response = match self.execute(url) {
      Ok(response) => response
      Err(error) => return Err(error)
    }
    if !self.follow_redirects ||
      response.status_code < 300U ||
      response.status_code > 399U {
      return Ok(response)
    }
    match response.header("Location") {
      Some(location) => url = resolve_redirect(url, location)
      None => return Ok(response)
    }
  }
  Err(TooManyRedirects)
}

///|
fn Request::execute(
  self : Request,
  url : String,
) -> Result[Response, RequestError] {
  let (scheme, authority, path) = match split_url(url) {
    Ok(parts) => parts
    Err(error) => return Err(error)
  }
  let entries : Array[(String, FixedArray[Byte])] = []
  for header in self.headers {
    let value = @utf8.encode(header.1)
    entries.push((header.0, value[0:].to_fixedarray()))
  }
  if self.body is Some(body) {
    let length = @utf8.encode(body.length().to_string())
    entries.push(("Content-Length", length[0:].to_fixedarray()))
  }
  let fields = match @http.Fields::from_list(entries) {
    Ok(fields) => fields
    Err(_) => return Err(InvalidHeader("invalid HTTP headers"))
  }
  let outgoing = @http.OutgoingRequest::outgoing_request(fields)
  guard outgoing.set_method(self.method_.to_wasi()) is Ok(_) else {
    return Err(InvalidUrl("invalid HTTP method"))
  }
  guard outgoing.set_scheme(Some(scheme)) is Ok(_) else {
    return Err(InvalidUrl("invalid URL scheme"))
  }
  guard outgoing.set_authority(Some(authority)) is Ok(_) else {
    return Err(InvalidUrl("invalid URL authority"))
  }
  guard outgoing.set_path_with_query(Some(path)) is Ok(_) else {
    return Err(InvalidUrl("invalid URL path"))
  }
  if self.body is Some(body) {
    let outgoing_body = match outgoing.body() {
      Ok(body) => body
      Err(_) => return Err(Io("could not open request body"))
    }
    let stream = match outgoing_body.write() {
      Ok(stream) => stream
      Err(_) => return Err(Io("could not open request stream"))
    }
    guard stream.blocking_write_and_flush(body[0:].to_fixedarray()) is Ok(_) else {
      stream.drop()
      return Err(Io("could not write request body"))
    }
    stream.drop()
    match @http.OutgoingBody::finish(outgoing_body, None) {
      Ok(_) => ()
      Err(error) => return Err(Http(error))
    }
  }
  let future = match @outgoing.handle(outgoing, None) {
    Ok(future) => future
    Err(error) => return Err(Http(error))
  }
  let pollable = future.subscribe()
  pollable.block()
  pollable.drop()
  let incoming = match future.get() {
    Some(Ok(Ok(response))) => response
    Some(Ok(Err(error))) => {
      future.drop()
      return Err(Http(error))
    }
    _ => {
      future.drop()
      return Err(Io("HTTP response was not ready"))
    }
  }
  future.drop()
  let status_code = incoming.status()
  let incoming_headers = incoming.headers()
  let headers : Array[(String, Bytes)] = []
  for header in incoming_headers.entries() {
    headers.push((header.0, Bytes::from_array(header.1)))
  }
  incoming_headers.drop()
  let body = match incoming.consume() {
    Ok(body) => body
    Err(_) => {
      incoming.drop()
      return Err(Io("could not consume response body"))
    }
  }
  let input = match body.stream() {
    Ok(input) => input
    Err(_) => {
      incoming.drop()
      return Err(Io("could not open response stream"))
    }
  }
  let content = @buffer.Buffer(size_hint=65536)
  for ;; {
    match input.blocking_read(65536UL) {
      Ok(chunk) => content.write_bytes(Bytes::from_array(chunk))
      Err(@streams.StreamError::Closed) => break
      Err(_) => {
        input.drop()
        incoming.drop()
        return Err(Io("failed while reading response body"))
      }
    }
  }
  input.drop()
  let trailers = @http.IncomingBody::finish(body)
  trailers.drop()
  incoming.drop()
  Ok({ status_code, headers, body: content.to_bytes(), })
}

///|
fn split_url(
  url : String,
) -> Result[(@http.Scheme, String, String), RequestError] {
  let (scheme, rest) = if url.has_prefix("https://") {
    (@http.Scheme::Https, url[8:])
  } else if url.has_prefix("http://") {
    (@http.Scheme::Http, url[7:])
  } else {
    return Err(InvalidUrl(url))
  }
  match rest.find("/") {
    Some(index) =>
      Ok((scheme, rest[0:index].to_owned(), rest[index:].to_owned()))
    None => Ok((scheme, rest.to_owned(), "/"))
  }
}

///|
fn resolve_redirect(base : String, location : String) -> String {
  if location.has_prefix("http://") || location.has_prefix("https://") {
    return location
  }
  match split_url(base) {
    Ok((@http.Scheme::Https, authority, _)) => "https://" + authority + location
    Ok((@http.Scheme::Http, authority, _)) => "http://" + authority + location
    _ => location
  }
}
