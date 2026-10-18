///|
priv struct SearchAnime {
  title : String
  first : Int32
  after : KitsuNullableJson[String]
} derive(ToJson)

///|
fn SearchAnime::execute(self : SearchAnime) -> Result[Json, @types.Error_] {
  @logging.log(
    @logging.Level::DEBUG,
    GRAPHQL_LOG_CONTEXT,
    "Executing SearchAnime query.",
  )
  let query : String =
    #|query SearchAnime($title: String!, $first: Int!, $after: String) {
    #|  searchAnimeByTitle(title: $title, first: $first, after: $after) {
    #|    nodes {
    #|      id
    #|      titles { translated romanized original }
    #|      description(locales: ["en", "en_us", "en_jp", "ja_jp"])
    #|      posterImage { original { url } }
    #|      subtype
    #|    }
    #|    pageInfo { hasNextPage endCursor }
    #|  }
    #|}
  GraphQLRequest::new(query, self).send()
}

///|
priv struct GetAnimeInfo {
  id : String
} derive(ToJson)

///|
fn GetAnimeInfo::execute(self : GetAnimeInfo) -> Result[Json, @types.Error_] {
  @logging.log(
    @logging.Level::DEBUG,
    GRAPHQL_LOG_CONTEXT,
    "Executing AnimeInfo query.",
  )
  let query : String =
    #|query AnimeInfo($id: ID!) {
    #|  findAnimeById(id: $id) {
    #|    id
    #|    titles { translated romanized original }
    #|    description(locales: ["en", "en_us", "en_jp", "ja_jp"])
    #|    posterImage { original { url } }
    #|    subtype
    #|  }
    #|}
  GraphQLRequest::new(query, self).send()
}

///|
priv struct GetAnimeEpisodes {
  id : String
  first : Int32
  after : KitsuNullableJson[String]
} derive(ToJson)

///|
fn GetAnimeEpisodes::execute(
  self : GetAnimeEpisodes,
) -> Result[Json, @types.Error_] {
  @logging.log(
    @logging.Level::DEBUG,
    GRAPHQL_LOG_CONTEXT,
    "Executing AnimeEpisodes query.",
  )
  let query : String =
    #|query AnimeEpisodes($id: ID!, $first: Int!, $after: String) {
    #|  findAnimeById(id: $id) {
    #|    episodes(first: $first, after: $after, sort: [{on: NUMBER, direction: ASCENDING}]) {
    #|      nodes {
    #|        id
    #|        number
    #|        titles { translated romanized original }
    #|        description(locales: ["en", "en_us", "en_jp", "ja_jp"])
    #|        thumbnail { original { url } }
    #|      }
    #|      pageInfo { hasNextPage endCursor }
    #|    }
    #|  }
    #|}
  GraphQLRequest::new(query, self).send()
}
