///|
priv struct KitsuTitlesJson {
  translated : KitsuNullableJson[String]
  romanized : KitsuNullableJson[String]
  original : KitsuNullableJson[String]
} derive(FromJson)

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
priv struct KitsuLocalizedJson {
  en : KitsuNullableJson[String]?
  en_us : KitsuNullableJson[String]?
  en_jp : KitsuNullableJson[String]?
  ja_jp : KitsuNullableJson[String]?
} derive(FromJson)

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
priv struct KitsuOriginalImageJson {
  url : String
} derive(FromJson)

///|
priv struct KitsuImageJson {
  original : KitsuOriginalImageJson
} derive(FromJson)

///|
priv struct KitsuSeriesJson {
  id : String
  titles : KitsuTitlesJson
  description : KitsuLocalizedJson
  poster_image : KitsuNullableJson[KitsuImageJson]
  subtype : String
} derive(FromJson(fields(poster_image(rename="posterImage"))))

///|
priv struct KitsuEpisodeJson {
  id : String
  number : Int
  titles : KitsuTitlesJson
  description : KitsuLocalizedJson
  thumbnail : KitsuNullableJson[KitsuImageJson]
} derive(FromJson)

///|
priv struct KitsuPageInfoJson {
  has_next_page : Bool
} derive(FromJson(fields(has_next_page(rename="hasNextPage"))))

///|
priv enum KitsuNullableJson[T] {
  NullValue
  Value(T)
}

///|
impl[T : FromJson] FromJson for KitsuNullableJson[T] with fn from_json(
  json,
  path,
) {
  match json {
    Null => NullValue
    value => Value(FromJson::from_json(value, path))
  }
}

///|
fn[T] KitsuNullableJson::to_option(self : KitsuNullableJson[T]) -> T? {
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
  errors : Array[Json]?
} derive(FromJson)

///|
fn[T] KitsuResponse::into_data(
  self : KitsuResponse[T],
) -> Result[T, @types.Error_] {
  guard self.data is Some(response_data) &&
    response_data.to_option() is Some(data) else {
    let message = match self.errors {
      Some(errors) if !errors.is_empty() =>
        "Kitsu GraphQL error: " + @json.to_json(errors).stringify()
      _ => "Kitsu GraphQL response contains no data"
    }
    return Err(@types.Error_::Other(Some(message)))
  }
  Ok(data)
}

///|
fn[T : FromJson] decode_response(json : Json) -> Result[T, @types.Error_] {
  let response : KitsuResponse[T] = @json.from_json(json) catch {
    error =>
      return Err(
        @types.Error_::Other(
          Some("invalid Kitsu response: " + error.to_string()),
        ),
      )
  }
  response.into_data()
}

///|
fn[T, U] paginate(
  source : KitsuConnectionJson[T],
  convert : (T) -> U?,
) -> (Array[U], Bool) {
  let nodes = source.nodes.to_option().unwrap_or([])
  let items = nodes
    .iter()
    .filter_map(node => node.to_option().bind(convert))
    .collect()
  (items, source.page_info.has_next_page)
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
fn KitsuSeriesJson::into_nero(self : KitsuSeriesJson) -> @types.Series {
  @types.Series::{
    id: self.id,
    title: self.titles.preferred().unwrap_or(""),
    poster_resource: self.poster_image
    .to_option()
    .bind(image => image.into_media_resource()),
    synopsis: self.description.preferred(),
    type_: Some(self.subtype),
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
) -> Result[@types.SeriesPage, @types.Error_] {
  let data : KitsuSearchDataJson = match decode_response(json) {
    Ok(data) => data
    Err(error) => return Err(error)
  }
  let source = data.search_anime_by_title
  let (series, has_next_page) = paginate(source, item => Some(item.into_nero()))
  Ok(@types.SeriesPage::{ series, has_next_page })
}

///|
fn @types.EpisodesPage::from_json(
  json : Json,
) -> Result[@types.EpisodesPage, @types.Error_] {
  let data : KitsuEpisodesDataJson = match decode_response(json) {
    Ok(data) => data
    Err(error) => return Err(error)
  }
  guard data.find_anime_by_id.to_option() is Some(anime) else {
    return Err(@types.Error_::NotFound)
  }
  let source = anime.episodes
  let (episodes, has_next_page) = paginate(source, item => item.into_nero())
  Ok(@types.EpisodesPage::{ episodes, has_next_page })
}
