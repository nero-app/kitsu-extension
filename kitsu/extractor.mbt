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
  let operation = SearchAnime::{
    title: query,
    first: PAGE_SIZE,
    after: KitsuNullableJson::from_option(cursor),
  }
  operation.execute().bind(json => @types.SeriesPage::from_json(json, cursor))
}

///|
pub fn get_series_info(
  series_id : String,
) -> Result[@types.Series, @types.Error_] {
  let operation = GetAnimeInfo::{ id: series_id, }
  operation.execute().bind(@types.Series::from_json)
}

///|
pub fn get_series_episodes(
  series_id : String,
  cursor : String?,
) -> Result[@types.EpisodesPage, @types.Error_] {
  let operation = GetAnimeEpisodes::{
    id: series_id,
    first: PAGE_SIZE,
    after: KitsuNullableJson::from_option(cursor),
  }
  operation.execute().bind(json => @types.EpisodesPage::from_json(json, cursor))
}
