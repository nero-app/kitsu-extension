///|
const SEARCH_ANIME_QUERY : String =
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

///|
const ANIME_INFO_QUERY : String =
  #|query AnimeInfo($id: ID!) {
  #|  findAnimeById(id: $id) {
  #|    id
  #|    titles { translated romanized original }
  #|    description(locales: ["en", "en_us", "en_jp", "ja_jp"])
  #|    posterImage { original { url } }
  #|    subtype
  #|  }
  #|}

///|
const ANIME_EPISODES_QUERY : String =
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
