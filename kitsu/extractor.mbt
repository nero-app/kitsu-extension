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
  operation
  .execute()
  .bind(json => {
    @types.SeriesPage::from_json(json, cursor)
    .map(page => {
      @logging.log(
        @logging.Level::TRACE,
        GRAPHQL_LOG_CONTEXT,
        "Loaded \{page.series.length()} search results; more pages: \{page.cursor is Some(_)}.",
      )
      page
    })
    .map_err(error => {
      @logging.log(
        @logging.Level::WARN,
        GRAPHQL_LOG_CONTEXT,
        "Could not read SearchAnime results: \{@debug.to_string(error)}.",
      )
      error
    })
  })
}

///|
pub fn get_series_info(
  series_id : String,
) -> Result[@types.Series, @types.Error_] {
  let operation = GetAnimeInfo::{ id: series_id, }
  operation
  .execute()
  .bind(json => {
    @types.Series::from_json(json).map_err(error => {
      @logging.log(
        if error is @types.Error_::NotFound {
          @logging.Level::DEBUG
        } else {
          @logging.Level::WARN
        },
        GRAPHQL_LOG_CONTEXT,
        "Could not read AnimeInfo for anime \{series_id}: \{@debug.to_string(error)}.",
      )
      error
    })
  })
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
  operation
  .execute()
  .bind(json => {
    @types.EpisodesPage::from_json(json, cursor)
    .map(page => {
      @logging.log(
        @logging.Level::TRACE,
        GRAPHQL_LOG_CONTEXT,
        "Loaded \{page.episodes.length()} episodes for anime \{series_id}; more pages: \{page.cursor is Some(_)}.",
      )
      page
    })
    .map_err(error => {
      @logging.log(
        if error is @types.Error_::NotFound {
          @logging.Level::DEBUG
        } else {
          @logging.Level::WARN
        },
        GRAPHQL_LOG_CONTEXT,
        "Could not read AnimeEpisodes for anime \{series_id}: \{@debug.to_string(error)}.",
      )
      error
    })
  })
}
