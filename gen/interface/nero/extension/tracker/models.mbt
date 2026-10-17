///|
priv struct ListEntriesVariables {
  status : String
  after : @kitsu.KitsuNullableJson[String]
} derive(ToJson)

///|
priv struct GetEntryVariables {
  id : String
} derive(ToJson)

///|
priv struct MutationVariables[T] {
  input : T
} derive(ToJson)

///|
priv struct DeleteEntryInput {
  id : String
} derive(ToJson)

///|
priv struct LibraryEntryJson {
  id : String
  media : @kitsu.KitsuNullableJson[@kitsu.KitsuSeriesJson]
  status : String
  progress : Int32
  rating : @kitsu.KitsuNullableJson[Int32]
  reconsume_count : Int32
  reconsuming : Bool
  notes : @kitsu.KitsuNullableJson[String]
} derive(FromJson(fields(reconsume_count(rename="reconsumeCount"))))

///|
priv struct LibraryEntryInput {
  id : String?
  media_id : String?
  media_type : String?
  status : String
  progress : UInt32
  rating : @kitsu.KitsuNullableJson[Int32]
  reconsume_count : UInt32
  reconsuming : Bool
  notes : @kitsu.KitsuNullableJson[String]
} derive (
  ToJson(
    fields(
      media_id(rename="mediaId"),
      media_type(rename="mediaType"),
      reconsume_count(rename="reconsumeCount"),
    ),
  ),
)

///|
priv struct PageInfoJson {
  has_next_page : Bool
  end_cursor : @kitsu.KitsuNullableJson[String]
} derive (
  FromJson(
    fields(has_next_page(rename="hasNextPage"), end_cursor(rename="endCursor")),
  ),
)

///|
priv struct EntriesConnectionJson {
  nodes : @kitsu.KitsuNullableJson[
    Array[@kitsu.KitsuNullableJson[LibraryEntryJson]],
  ]
  page_info : PageInfoJson
} derive(FromJson(fields(page_info(rename="pageInfo"))))

///|
priv struct LibraryJson {
  all : EntriesConnectionJson
} derive(FromJson)

///|
priv struct ProfileJson {
  library : LibraryJson
} derive(FromJson)

///|
priv struct ListDataJson {
  current_profile : @kitsu.KitsuNullableJson[ProfileJson]
} derive(FromJson(fields(current_profile(rename="currentProfile"))))

///|
priv struct EntryAnimeJson {
  my_library_entry : @kitsu.KitsuNullableJson[LibraryEntryJson]
} derive(FromJson(fields(my_library_entry(rename="myLibraryEntry"))))

///|
priv struct EntryDataJson {
  current_profile : @kitsu.KitsuNullableJson[Json]
  find_anime_by_id : @kitsu.KitsuNullableJson[EntryAnimeJson]
} derive (
  FromJson(
    fields(
      current_profile(rename="currentProfile"),
      find_anime_by_id(rename="findAnimeById"),
    ),
  ),
)

///|
priv struct MutationPayloadJson[T] {
  errors : @kitsu.KitsuNullableJson[Array[Json]]?
  library_entry : @kitsu.KitsuNullableJson[T]
} derive(FromJson(fields(library_entry(rename="libraryEntry"))))

///|
priv struct MutationRootJson[T] {
  result : @kitsu.KitsuNullableJson[MutationPayloadJson[T]]
} derive(FromJson)

///|
priv struct MutationDataJson[T] {
  library_entry : @kitsu.KitsuNullableJson[MutationRootJson[T]]
} derive(FromJson(fields(library_entry(rename="libraryEntry"))))

///|
fn[T] MutationDataJson::result(
  self : MutationDataJson[T],
) -> Result[T, @types.Error_] {
  guard self.library_entry.to_option() is Some(root) &&
    root.result.to_option() is Some(payload) else {
    return Err(@types.Error_::Other(Some("Kitsu returned no mutation result")))
  }
  let errors = payload.errors.bind(value => value.to_option()).unwrap_or([])
  if !errors.is_empty() {
    return Err(@kitsu.graphql_errors(errors))
  }
  match payload.library_entry.to_option() {
    Some(entry) => Ok(entry)
    None => Err(@types.Error_::Other(Some("Kitsu returned no library entry")))
  }
}

///|
fn WatchStatus::to_kitsu(self : WatchStatus) -> String {
  match self {
    WATCHING => "CURRENT"
    COMPLETED => "COMPLETED"
    ON_HOLD => "ON_HOLD"
    DROPPED => "DROPPED"
    PLAN_TO_WATCH => "PLANNED"
  }
}

///|
fn LibraryEntryJson::into_nero(
  self : LibraryEntryJson,
) -> Result[Entry, @types.Error_] {
  guard self.media.to_option() is Some(media) else {
    return Err(@types.Error_::NotFound)
  }
  let status = match self.status {
    "CURRENT" => WATCHING
    "COMPLETED" => COMPLETED
    "ON_HOLD" => ON_HOLD
    "DROPPED" => DROPPED
    "PLANNED" => PLAN_TO_WATCH
    _ => return Err(@types.Error_::Other(Some("Unknown Kitsu library status")))
  }
  guard self.progress >= 0 && self.reconsume_count >= 0 else {
    return Err(@types.Error_::Other(Some("Invalid Kitsu tracking progress")))
  }
  let score = match self.rating.to_option() {
    None => None
    Some(rating) if rating >= 2 && rating <= 20 => Some((rating * 5).to_byte())
    _ => return Err(@types.Error_::Other(Some("Invalid Kitsu rating")))
  }
  Ok({
    series: media.into_nero(),
    status,
    details: {
      progress: self.progress.reinterpret_as_uint(),
      score,
      repeat_count: self.reconsume_count.reinterpret_as_uint(),
      notes: self.notes.to_option(),
    },
  })
}

///|
fn EntryDetails::to_kitsu(
  self : EntryDetails,
  status : WatchStatus,
) -> Result[LibraryEntryInput, @types.Error_] {
  guard self.progress <= 2147483647U && self.repeat_count <= 50U else {
    return Err(
      @types.Error_::Other(Some("Tracking counts exceed Kitsu limits")),
    )
  }
  let rating : Int32? = match self.score {
    None => None
    Some(score) if score.to_int() >= 1 && score.to_int() <= 100 => {
      let rating = (score.to_int() + 2) / 5
      Some(if rating < 2 { 2 } else { rating })
    }
    _ =>
      return Err(@types.Error_::Other(Some("Score must be between 1 and 100")))
  }
  Ok({
    id: None,
    media_id: None,
    media_type: None,
    status: status.to_kitsu(),
    progress: self.progress,
    rating: @kitsu.KitsuNullableJson::from_option(rating),
    reconsume_count: self.repeat_count,
    reconsuming: false,
    notes: @kitsu.KitsuNullableJson::from_option(self.notes),
  })
}
