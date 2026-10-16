///|
const PAGE_SIZE : Int32 = 20

///|
pub fn filters() -> Result[Array[@types.FilterCategory], @types.Error_] {
  Ok([])
}

///|
pub fn search(
  query : String,
  cursor : String?,
  _filters : Array[@types.SearchFilter],
) -> Result[@types.SeriesPage, @types.Error_] {
  let variables : Json = {
    "title": query,
    "first": PAGE_SIZE.to_double(),
    "after": @json.to_json(KitsuNullableJson::from_option(cursor)),
  }
  execute_query(SEARCH_ANIME_QUERY, variables).bind(json => {
    @types.SeriesPage::from_json(json, cursor)
  })
}

///|
pub fn get_series_info(
  series_id : String,
) -> Result[@types.Series, @types.Error_] {
  let variables : Json = { "id": series_id }
  execute_query(ANIME_INFO_QUERY, variables).bind(@types.Series::from_json)
}

///|
pub fn get_series_episodes(
  series_id : String,
  cursor : String?,
) -> Result[@types.EpisodesPage, @types.Error_] {
  let variables : Json = {
    "id": series_id,
    "first": PAGE_SIZE.to_double(),
    "after": @json.to_json(KitsuNullableJson::from_option(cursor)),
  }
  execute_query(ANIME_EPISODES_QUERY, variables).bind(json => {
    @types.EpisodesPage::from_json(json, cursor)
  })
}

///|
pub fn get_series_videos(
  _series_id : String,
  _episode_id : String,
) -> Result[Array[@types.Video], @types.Error_] {
  Ok([])
}
