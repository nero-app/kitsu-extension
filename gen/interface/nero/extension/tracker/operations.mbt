///|
const ENTRY_FRAGMENT : String =
  #|fragment TrackedEntry on LibraryEntry {
  #|  id status progress rating reconsumeCount reconsuming notes
  #|  media {
  #|    id
  #|    titles { translated romanized original }
  #|    description(locales: ["en", "en_us", "en_jp", "ja_jp"])
  #|    posterImage { original { url } }
  #|    ... on Anime { subtype }
  #|  }
  #|}

///|
const LIST_ENTRIES_QUERY : String =
  #|query TrackedSeries($status: LibraryEntryStatusEnum!, $after: String) {
  #|  currentProfile {
  #|    library {
  #|      all(first: 20, after: $after, mediaType: ANIME, status: [$status], sort: [{on: UPDATED_AT, direction: DESCENDING}]) {
  #|        nodes { ...TrackedEntry }
  #|        pageInfo { hasNextPage endCursor }
  #|      }
  #|    }
  #|  }
  #|}

///|
const GET_ENTRY_QUERY : String =
  #|query TrackedSeriesEntry($id: ID!) {
  #|  currentProfile { id }
  #|  findAnimeById(id: $id) {
  #|    myLibraryEntry { ...TrackedEntry }
  #|  }
  #|}

///|
const CREATE_ENTRY_MUTATION : String =
  #|mutation SaveTrackedSeries($input: LibraryEntryCreateInput!) {
  #|  libraryEntry {
  #|    result: create(input: $input) {
  #|      errors { __typename code message }
  #|      libraryEntry { ...TrackedEntry }
  #|    }
  #|  }
  #|}

///|
const UPDATE_ENTRY_MUTATION : String =
  #|mutation UpdateTrackedSeries($input: LibraryEntryUpdateInput!) {
  #|  libraryEntry {
  #|    result: update(input: $input) {
  #|      errors { __typename code message }
  #|      libraryEntry { ...TrackedEntry }
  #|    }
  #|  }
  #|}

///|
const REMOVE_ENTRY_MUTATION : String =
  #|mutation RemoveTrackedSeries($input: GenericDeleteInput!) {
  #|  libraryEntry {
  #|    result: delete(input: $input) {
  #|      errors { __typename code message }
  #|      libraryEntry { id }
  #|    }
  #|  }
  #|}
