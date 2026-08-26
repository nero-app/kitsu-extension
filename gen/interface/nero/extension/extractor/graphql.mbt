///|
const KITSU_GRAPHQL_ENDPOINT = "https://kitsu.io/api/graphql"

///|
priv enum KitsuError {
  Request(@request.RequestError)
  Unauthorized
  Forbidden
  NotFound
  HttpStatus(UInt)
}

///|
fn KitsuError::message(self : KitsuError) -> String {
  match self {
    Request(error) => error.message()
    Unauthorized => "Kitsu authorization failed"
    Forbidden => "Kitsu denied the request"
    NotFound => "Kitsu resource not found"
    HttpStatus(status) => "Kitsu returned HTTP " + status.to_string()
  }
}

///|
fn execute_query(query : String, variables : Json) -> Result[Json, KitsuError] {
  let payload : Json = { "query": query, "variables": variables }
  let request = match
    @request.Request::new(@request.Method::Post, KITSU_GRAPHQL_ENDPOINT).header(
      "Accept", "application/json",
    ) {
    Ok(request) => request
    Err(error) => return Err(Request(error))
  }
  let response = match request.with_json(payload).send() {
    Ok(response) => response
    Err(error) => return Err(Request(error))
  }
  if response.status_code >= 200U && response.status_code <= 299U {
    match response.json() {
      Ok(json) => Ok(json)
      Err(error) => Err(Request(error))
    }
  } else {
    match response.status_code {
      401 => Err(Unauthorized)
      403 => Err(Forbidden)
      404 => Err(NotFound)
      status => Err(HttpStatus(status))
    }
  }
}

///|
fn kitsu_error(error : KitsuError) -> @types.Error_ {
  match error {
    Unauthorized => @types.Error_::Unauthorized
    Forbidden => @types.Error_::Forbidden
    NotFound => @types.Error_::NotFound
    Request(@request.RequestError::Http(code)) => @types.Error_::Http(code)
    other => @types.Error_::Other(Some(other.message()))
  }
}
