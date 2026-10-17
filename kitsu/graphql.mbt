///|
const KITSU_GRAPHQL_ENDPOINT = "https://kitsu.io/api/graphql"

///|
pub struct GraphQLRequest[V] {
  query : String
  variables : V
} derive(ToJson)

///|
pub extend GraphQLRequest with ToJson::{to_json}

///|
pub fn[V] GraphQLRequest::new(
  query : String,
  variables : V,
) -> GraphQLRequest[V] {
  { query, variables, }
}

///|
pub fn[V : ToJson] GraphQLRequest::send(
  self : GraphQLRequest[V],
) -> Result[Json, @types.Error_] {
  self.send_request(
    @request.Request::new(@request.Method::Post, KITSU_GRAPHQL_ENDPOINT),
  )
}

///|
fn[V : ToJson] GraphQLRequest::send_request(
  self : GraphQLRequest[V],
  request : @request.Request,
) -> Result[Json, @types.Error_] {
  let response = match
    request
    .follow_redirects(false)
    .header("Accept", "application/json")
    .bind(request => request.with_json(self).send()) {
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
pub fn[V : ToJson, T : FromJson, U] GraphQLRequest::send_authenticated(
  self : GraphQLRequest[V],
  resolve : (T) -> Result[U, @types.Error_],
) -> Result[U, @types.Error_] {
  for refresh in [false, true] {
    let token = match @session.access_token(refresh~) {
      Ok(token) => token
      Err(error) => return Err(error)
    }
    let result = @request.Request::new(
        @request.Method::Post,
        KITSU_GRAPHQL_ENDPOINT,
      )
      .header("Authorization", "Bearer " + token)
      .map_err(error => error.into_nero())
      .bind(request => self.send_request(request))
      .bind(json => decode_authenticated_response(json))
      .bind(resolve)
    match result {
      Err(@types.Error_::Unauthorized) if !refresh => continue
      result => return result
    }
  }
  Err(@types.Error_::Unauthorized)
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
