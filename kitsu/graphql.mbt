///|
const KITSU_GRAPHQL_ENDPOINT = "https://kitsu.io/api/graphql"

///|
fn execute_query(
  query : String,
  variables : Json,
  token~ : String? = None,
) -> Result[Json, @types.Error_] {
  let request = @request.Request::new(
    @request.Method::Post,
    KITSU_GRAPHQL_ENDPOINT,
  ).follow_redirects(false)
  match request.header("Accept", "application/json") {
    Ok(_) => ()
    Err(error) => return Err(error.into_nero())
  }
  if token is Some(token) {
    match request.header("Authorization", "Bearer " + token) {
      Ok(_) => ()
      Err(error) => return Err(error.into_nero())
    }
  }
  let payload : Json = { "query": query, "variables": variables }
  let response = match request.with_json(payload).send() {
    Ok(response) => response
    Err(error) => return Err(error.into_nero())
  }
  match response.status_code {
    401 => return Err(@types.Error_::Unauthorized)
    403 => return Err(@types.Error_::Forbidden)
    404 => return Err(@types.Error_::NotFound)
    status if status < 200U || status >= 300U =>
      return Err(
        @types.Error_::Other(Some("Kitsu returned HTTP " + status.to_string())),
      )
    _ => ()
  }
  response.json().map_err(error => error.into_nero())
}

///|
fn @request.RequestError::into_nero(
  self : @request.RequestError,
) -> @types.Error_ {
  match self {
    @request.RequestError::Http(code) => @types.Error_::Http(code)
    _ => @types.Error_::Other(Some(self.message()))
  }
}

///|
pub fn[T : FromJson, U] authenticated_query(
  query : String,
  variables : Json,
  resolve : (T) -> Result[U, @types.Error_],
) -> Result[U, @types.Error_] {
  let token = match @session.access_token() {
    Ok(token) => token
    Err(error) => return Err(error)
  }
  let result = execute_query(query, variables, token=Some(token))
    .bind(json => decode_authenticated_response(json))
    .bind(resolve)
  match result {
    Err(@types.Error_::Unauthorized) =>
      @session.access_token(refresh=true)
      .bind(token => execute_query(query, variables, token=Some(token)))
      .bind(json => decode_authenticated_response(json))
      .bind(resolve)
    _ => result
  }
}

///|
fn[T : FromJson] decode_authenticated_response(
  json : Json,
) -> Result[T, @types.Error_] {
  let data : Json = match decode_response(json) {
    Ok(data) => data
    Err(error) => return Err(error)
  }
  if data is { "currentProfile": Null, .. } {
    return Err(@types.Error_::Unauthorized)
  }
  decode_json(data)
}

///|
pub fn graphql_errors(errors : Array[Json]) -> @types.Error_ {
  for error in errors {
    match error {
      { "__typename": "NotAuthenticatedError", .. } =>
        return @types.Error_::Unauthorized
      { "__typename": "NotAuthorizedError", .. } =>
        return @types.Error_::Forbidden
      { "__typename": "NotFoundError", .. } => return @types.Error_::NotFound
      _ => ()
    }
    match error {
      { "extensions": { "code": String(code), .. }, .. }
      | { "code": String(code), .. } =>
        match code {
          "NotAuthenticated" | "UNAUTHENTICATED" | "NOT_AUTHENTICATED" =>
            return @types.Error_::Unauthorized
          "NotAuthorized" | "FORBIDDEN" | "NOT_AUTHORIZED" =>
            return @types.Error_::Forbidden
          "NotFound" | "NOT_FOUND" => return @types.Error_::NotFound
          _ => ()
        }
      _ => ()
    }
  }
  let messages = errors
    .iter()
    .filter_map(error => {
      match error {
        { "message": String(message), .. } => Some(message)
        _ => None
      }
    })
    .collect()
  @types.Error_::Other(Some("Kitsu GraphQL error: " + messages.join("; ")))
}
