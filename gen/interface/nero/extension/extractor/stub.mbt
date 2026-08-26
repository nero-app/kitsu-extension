///|
const PAGE_SIZE : Int = 20

///|
pub fn filters() -> Result[Array[@types.FilterCategory], @types.Error_] {
  Ok([])
}

///|
pub fn search(
  query : String,
  page : UInt?,
  _filters : Array[@types.SearchFilter],
) -> Result[@types.SeriesPage, @types.Error_] {
  let page_number = match page {
    Some(value) if value > 0U => value.reinterpret_as_int()
    _ => 1
  }
  let data = match
    execute_query(
      SEARCH_ANIME_QUERY,
      (
        {
          "title": query,
          "first": PAGE_SIZE.to_double(),
          "after": page_cursor(page_number),
        } : Json),
    ) {
    Ok(data) => data
    Err(error) => return Err(kitsu_error(error))
  }
  @types.SeriesPage::from_json(data)
}

///|
pub fn get_series_info(
  series_id : String,
) -> Result[@types.Series, @types.Error_] {
  let data = match
    execute_query(ANIME_INFO_QUERY, ({ "id": series_id } : Json)) {
    Ok(data) => data
    Err(error) => return Err(kitsu_error(error))
  }
  @types.Series::from_json(data)
}

///|
pub fn get_series_episodes(
  series_id : String,
  page : UInt?,
) -> Result[@types.EpisodesPage, @types.Error_] {
  let page_number = match page {
    Some(value) if value > 0U => value.reinterpret_as_int()
    _ => 1
  }
  let data = match
    execute_query(
      ANIME_EPISODES_QUERY,
      (
        {
          "id": series_id,
          "first": PAGE_SIZE.to_double(),
          "after": page_cursor(page_number),
        } : Json),
    ) {
    Ok(data) => data
    Err(error) => return Err(kitsu_error(error))
  }
  @types.EpisodesPage::from_json(data)
}

///|
pub fn get_series_videos(
  _series_id : String,
  _episode_id : String,
) -> Result[Array[@types.Video], @types.Error_] {
  Ok([])
}

///|
fn page_cursor(page : Int) -> Json {
  if page <= 1 {
    (null : Json)
  } else {
    @json.to_json(
      @base64.encode(
        @utf8.encode(((page - 1) * PAGE_SIZE).to_string()),
        padding=false,
      ),
    )
  }
}
