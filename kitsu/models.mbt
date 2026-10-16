///|
pub(all) struct KitsuTitlesJson {
  translated : KitsuNullableJson[String]
  romanized : KitsuNullableJson[String]
  original : KitsuNullableJson[String]
} derive(FromJson)

///|
pub extend KitsuTitlesJson with @json.FromJson::{from_json}

///|
fn KitsuTitlesJson::preferred(self : KitsuTitlesJson) -> String? {
  for
    value in [
      self.translated.to_option(),
      self.romanized.to_option(),
      self.original.to_option(),
    ] {
    if value is Some(title) && !title.is_empty() {
      return Some(title)
    }
  }
  None
}

///|
pub(all) struct KitsuLocalizedJson {
  en : KitsuNullableJson[String]?
  en_us : KitsuNullableJson[String]?
  en_jp : KitsuNullableJson[String]?
  ja_jp : KitsuNullableJson[String]?
} derive(FromJson)

///|
pub extend KitsuLocalizedJson with @json.FromJson::{from_json}

///|
fn KitsuLocalizedJson::preferred(self : KitsuLocalizedJson) -> String? {
  for
    value in [
      self.en.bind(value => value.to_option()),
      self.en_us.bind(value => value.to_option()),
      self.en_jp.bind(value => value.to_option()),
      self.ja_jp.bind(value => value.to_option()),
    ] {
    if value is Some(text) && !text.is_empty() {
      return Some(text)
    }
  }
  None
}

///|
pub(all) struct KitsuOriginalImageJson {
  url : String
} derive(FromJson)

///|
pub extend KitsuOriginalImageJson with @json.FromJson::{from_json}

///|
pub(all) struct KitsuImageJson {
  original : KitsuOriginalImageJson
} derive(FromJson)

///|
pub extend KitsuImageJson with @json.FromJson::{from_json}

///|
pub(all) struct KitsuSeriesJson {
  id : String
  titles : KitsuTitlesJson
  description : KitsuLocalizedJson
  poster_image : KitsuNullableJson[KitsuImageJson]
  subtype : KitsuNullableJson[String]?
} derive(FromJson(fields(poster_image(rename="posterImage"))))

///|
pub extend KitsuSeriesJson with @json.FromJson::{from_json}

///|
priv struct KitsuEpisodeJson {
  id : String
  number : Int32
  titles : KitsuTitlesJson
  description : KitsuLocalizedJson
  thumbnail : KitsuNullableJson[KitsuImageJson]
} derive(FromJson)

///|
priv struct KitsuPageInfoJson {
  has_next_page : Bool
  end_cursor : KitsuNullableJson[String]
} derive (
  FromJson(
    fields(has_next_page(rename="hasNextPage"), end_cursor(rename="endCursor")),
  ),
)

///|
pub(all) enum KitsuNullableJson[T] {
  NullValue
  Value(T)
}

///|
pub impl[T : FromJson] FromJson for KitsuNullableJson[T] with fn from_json(
  json,
  path,
) {
  match json {
    Null => NullValue
    value => Value(FromJson::from_json(value, path))
  }
}

///|
pub impl[T : ToJson] ToJson for KitsuNullableJson[T] with fn to_json(self) {
  match self {
    Value(value) => @json.to_json(value)
    NullValue => (null : Json)
  }
}

///|
pub extend KitsuNullableJson with @json.FromJson::{from_json}

///|
pub extend KitsuNullableJson with ToJson::{to_json}

///|
pub fn[T] KitsuNullableJson::from_option(value : T?) -> KitsuNullableJson[T] {
  match value {
    Some(value) => Value(value)
    None => NullValue
  }
}

///|
pub fn[T] KitsuNullableJson::to_option(self : KitsuNullableJson[T]) -> T? {
  match self {
    Value(item) => Some(item)
    NullValue => None
  }
}

///|
priv struct KitsuConnectionJson[T] {
  nodes : KitsuNullableJson[Array[KitsuNullableJson[T]]]
  page_info : KitsuPageInfoJson
} derive(FromJson(fields(page_info(rename="pageInfo"))))

///|
priv struct KitsuSearchDataJson {
  search_anime_by_title : KitsuConnectionJson[KitsuSeriesJson]
} derive(FromJson(fields(search_anime_by_title(rename="searchAnimeByTitle"))))

///|
priv struct KitsuInfoDataJson {
  find_anime_by_id : KitsuNullableJson[KitsuSeriesJson]
} derive(FromJson(fields(find_anime_by_id(rename="findAnimeById"))))

///|
priv struct KitsuEpisodesAnimeJson {
  episodes : KitsuConnectionJson[KitsuEpisodeJson]
} derive(FromJson)

///|
priv struct KitsuEpisodesDataJson {
  find_anime_by_id : KitsuNullableJson[KitsuEpisodesAnimeJson]
} derive(FromJson(fields(find_anime_by_id(rename="findAnimeById"))))

///|
priv struct KitsuResponse[T] {
  data : KitsuNullableJson[T]?
  errors : KitsuNullableJson[Array[Json]]?
} derive(FromJson)

///|
fn[T] KitsuResponse::into_data(
  self : KitsuResponse[T],
) -> Result[T, @types.Error_] {
  let errors = self.errors.bind(value => value.to_option()).unwrap_or([])
  if !errors.is_empty() {
    return Err(graphql_errors(errors))
  }
  guard self.data is Some(response_data) &&
    response_data.to_option() is Some(data) else {
    return Err(
      @types.Error_::Other(Some("Kitsu GraphQL response contains no data")),
    )
  }
  Ok(data)
}

///|
pub fn[T : FromJson] decode_response(json : Json) -> Result[T, @types.Error_] {
  decode_json(json)
  .bind((response : KitsuResponse[Json]) => response.into_data())
  .bind(data => decode_json(data))
}

///|
fn[T : FromJson] decode_json(json : Json) -> Result[T, @types.Error_] {
  let value : T = @json.from_json(json) catch {
    error =>
      return Err(
        @types.Error_::Other(
          Some("invalid Kitsu response: " + error.to_string()),
        ),
      )
  }
  Ok(value)
}

///|
fn[T, U] KitsuConnectionJson::paginate(
  self : KitsuConnectionJson[T],
  cursor : String?,
  convert : (T) -> U?,
) -> Result[(Array[U], String?), @types.Error_] {
  let nodes = self.nodes.to_option().unwrap_or([])
  let items = nodes
    .iter()
    .filter_map(node => node.to_option().bind(convert))
    .collect()
  let next = if self.page_info.has_next_page {
    guard self.page_info.end_cursor.to_option() is Some(next) &&
      Some(next) != cursor else {
      return Err(
        @types.Error_::Other(
          Some("Kitsu returned an invalid continuation cursor"),
        ),
      )
    }
    Some(next)
  } else {
    None
  }
  Ok((items, next))
}

///|
fn KitsuImageJson::into_media_resource(
  self : KitsuImageJson,
) -> @types.MediaResource? {
  let url = self.original.url
  guard url.has_prefix("https://") else { return None }
  let rest = url[8:]
  let (authority, path) = match rest.find("/") {
    Some(index) => (rest[0:index].to_owned(), rest[index:].to_owned())
    None => (rest.to_owned(), "/")
  }
  let request = @types0.OutgoingRequest::outgoing_request(
    @types0.Fields::fields(),
  )
  guard request.set_method(@types0.Method::Get) is Ok(_) else { return None }
  guard request.set_scheme(Some(@types0.Scheme::Https)) is Ok(_) else {
    return None
  }
  guard request.set_authority(Some(authority)) is Ok(_) else { return None }
  guard request.set_path_with_query(Some(path)) is Ok(_) else { return None }
  Some(@types.MediaResource::HttpRequest(request))
}

///|
pub fn KitsuSeriesJson::into_nero(self : KitsuSeriesJson) -> @types.Series {
  @types.Series::{
    id: self.id,
    title: self.titles.preferred().unwrap_or(""),
    poster_resource: self.poster_image
    .to_option()
    .bind(image => image.into_media_resource()),
    synopsis: self.description.preferred(),
    type_: self.subtype.bind(value => value.to_option()),
  }
}

///|
fn KitsuEpisodeJson::into_nero(self : KitsuEpisodeJson) -> @types.Episode? {
  guard self.number >= 0 && self.number <= 65535 else { return None }
  Some(@types.Episode::{
    id: self.id,
    number: self.number.reinterpret_as_uint(),
    title: self.titles.preferred(),
    thumbnail_resource: self.thumbnail
    .to_option()
    .bind(image => image.into_media_resource()),
    description: self.description.preferred(),
  })
}

///|
fn @types.Series::from_json(
  json : Json,
) -> Result[@types.Series, @types.Error_] {
  let data : KitsuInfoDataJson = match decode_response(json) {
    Ok(data) => data
    Err(error) => return Err(error)
  }
  match data.find_anime_by_id.to_option() {
    Some(series) => Ok(series.into_nero())
    None => Err(@types.Error_::NotFound)
  }
}

///|
fn @types.SeriesPage::from_json(
  json : Json,
  cursor : String?,
) -> Result[@types.SeriesPage, @types.Error_] {
  let data : KitsuSearchDataJson = match decode_response(json) {
    Ok(data) => data
    Err(error) => return Err(error)
  }
  data.search_anime_by_title
  .paginate(cursor, item => Some(item.into_nero()))
  .map(page => {
    let (series, cursor) = page
    @types.SeriesPage::{ series, cursor, }
  })
}

///|
fn @types.EpisodesPage::from_json(
  json : Json,
  cursor : String?,
) -> Result[@types.EpisodesPage, @types.Error_] {
  let data : KitsuEpisodesDataJson = match decode_response(json) {
    Ok(data) => data
    Err(error) => return Err(error)
  }
  guard data.find_anime_by_id.to_option() is Some(anime) else {
    return Err(@types.Error_::NotFound)
  }
  let source = anime.episodes
  source
  .paginate(cursor, item => item.into_nero())
  .map(page => {
    let (episodes, cursor) = page
    @types.EpisodesPage::{ episodes, cursor, }
  })
}
