///|
const TOKEN_ENDPOINT = "https://kitsu.io/api/oauth/token"

///|
const TOKEN_KEY = "kitsu.oauth.session"

///|
priv struct Token {
  access_token : String
  refresh_token : String?
} derive(ToJson)

///|
impl FromJson for Token with fn from_json(json, path) {
  guard json is { "access_token": access_token, .. } else {
    raise @json.JsonDecodeError((path, "Expected token with access_token"))
  }
  let refresh_token = match json {
    { "refresh_token": Null, .. } => None
    { "refresh_token": value, .. } =>
      Some(@json.from_json(value, path=path.add_key("refresh_token")))
    _ => None
  }
  {
    access_token: @json.from_json(
      access_token,
      path=path.add_key("access_token"),
    ),
    refresh_token,
  }
}

///|
fn Token::load() -> Result[Token?, @types.Error_] {
  let bucket = match @store.open("") {
    Ok(bucket) => bucket
    Err(_) =>
      return Err(
        @types.Error_::Other(Some("Could not open Kitsu session storage")),
      )
  }
  defer bucket.drop()
  match bucket.get(TOKEN_KEY) {
    Ok(Some(bytes)) => {
      let token : Token = @json.from_json(
        @json.parse(@utf8.decode(Bytes::from_array(bytes))),
      ) catch {
        _ => return Ok(None)
      }
      Ok(Some(token))
    }
    Ok(None) => Ok(None)
    Err(_) => Err(@types.Error_::Other(Some("Could not read Kitsu session")))
  }
}

///|
fn Token::store(self : Token) -> Result[Unit, @types.Error_] {
  let bucket = match @store.open("") {
    Ok(bucket) => bucket
    Err(_) =>
      return Err(
        @types.Error_::Other(Some("Could not open Kitsu session storage")),
      )
  }
  defer bucket.drop()
  let bytes = @utf8.encode(@json.to_json(self).stringify())
  bucket
  .set(TOKEN_KEY, bytes[0:].to_fixedarray(), None)
  .map_err(_ => @types.Error_::Other(Some("Could not store Kitsu session")))
}

///|
fn Token::refresh(self : Token) -> Result[Token, @types.Error_] {
  guard self.refresh_token is Some(refresh_token) else {
    return Err(@types.Error_::Unauthorized)
  }
  let payload : Json = {
    "grant_type": "refresh_token",
    "refresh_token": refresh_token,
  }
  exchange(payload).map(renewed => {
    access_token: renewed.access_token,
    refresh_token: Some(renewed.refresh_token.unwrap_or(refresh_token)),
  })
}

///|
fn exchange(payload : Json) -> Result[Token, @types.Error_] {
  let response = match
    @request.Request::new(@request.Method::Post, TOKEN_ENDPOINT)
    .follow_redirects(false)
    .with_json(payload)
    .send() {
    Ok(response) => response
    Err(@request.RequestError::Http(code)) =>
      return Err(@types.Error_::Http(code))
    Err(_) =>
      return Err(
        @types.Error_::Other(Some("Could not reach Kitsu authentication")),
      )
  }
  if response.status_code == 400U || response.status_code == 401U {
    return Err(@types.Error_::Unauthorized)
  }
  if response.status_code == 403U {
    return Err(@types.Error_::Forbidden)
  }
  guard response.status_code >= 200U && response.status_code < 300U else {
    return Err(
      @types.Error_::Other(
        Some(
          "Kitsu authentication returned HTTP " +
          response.status_code.to_string(),
        ),
      ),
    )
  }
  let json = match response.json() {
    Ok(json) => json
    Err(_) =>
      return Err(
        @types.Error_::Other(Some("Invalid Kitsu authentication response")),
      )
  }
  let token : Token = @json.from_json(json) catch {
    _ =>
      return Err(
        @types.Error_::Other(Some("Invalid Kitsu authentication response")),
      )
  }
  if token.access_token.is_empty() {
    return Err(@types.Error_::Unauthorized)
  }
  Ok(token)
}

///|
fn login() -> Result[Token, @types.Error_] {
  let username = @interaction.request_text({
    title: "Sign in to Kitsu",
    description: Some("Enter your Kitsu email or username."),
    placeholder: Some("Email or username"),
    initial_value: None,
    sensitive: false,
    reference: None,
  })
  guard username is Some(username) && !username.is_empty() else {
    return Err(@types.Error_::Unauthorized)
  }
  let password = @interaction.request_text({
    title: "Sign in to Kitsu",
    description: Some("Enter your Kitsu password."),
    placeholder: Some("Password"),
    initial_value: None,
    sensitive: true,
    reference: None,
  })
  guard password is Some(password) && !password.is_empty() else {
    return Err(@types.Error_::Unauthorized)
  }
  let payload : Json = {
    "grant_type": "password",
    "username": username,
    "password": password,
  }
  exchange(payload)
}

///|
pub fn access_token(refresh? : Bool = false) -> Result[String, @types.Error_] {
  let stored = match Token::load() {
    Ok(stored) => stored
    Err(error) => return Err(error)
  }
  if !refresh && stored is Some(token) {
    return Ok(token.access_token)
  }
  if stored is Some(token) {
    match token.refresh() {
      Ok(renewed) => return renewed.store().map(_ => renewed.access_token)
      Err(@types.Error_::Unauthorized) => ()
      Err(error) => return Err(error)
    }
  }
  login().bind(token => token.store().map(_ => token.access_token))
}
