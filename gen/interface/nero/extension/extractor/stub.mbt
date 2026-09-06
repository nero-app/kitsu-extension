///|
pub fn filters() -> Result[Array[@types.FilterCategory], @types.Error_] {
  @kitsu.filters()
}

///|
pub fn search(
  query : String,
  page : UInt?,
  filters : Array[@types.SearchFilter],
) -> Result[@types.SeriesPage, @types.Error_] {
  @kitsu.search(query, page, filters)
}

///|
pub fn get_series_info(
  series_id : String,
) -> Result[@types.Series, @types.Error_] {
  @kitsu.get_series_info(series_id)
}

///|
pub fn get_series_episodes(
  series_id : String,
  page : UInt?,
) -> Result[@types.EpisodesPage, @types.Error_] {
  @kitsu.get_series_episodes(series_id, page)
}

///|
pub fn get_series_videos(
  series_id : String,
  episode_id : String,
) -> Result[Array[@types.Video], @types.Error_] {
  @kitsu.get_series_videos(series_id, episode_id)
}
