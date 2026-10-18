///|
const LOG_CONTEXT : String = "tracker"

///|
pub fn list_entries(
  status : WatchStatus,
  cursor : String?,
) -> Result[EntriesPage, @types.Error_] {
  @logging.log(
    @logging.Level::DEBUG,
    LOG_CONTEXT,
    "Fetching library entries with status \{status.to_kitsu()}.",
  )
  let variables = ListEntriesVariables::{
    status: status.to_kitsu(),
    after: @kitsu.KitsuNullableJson::from_option(cursor),
  }
  let data : ListDataJson = match
    @kitsu.GraphQLRequest::new(
      LIST_ENTRIES_QUERY + "\n" + ENTRY_FRAGMENT,
      variables,
    ).send_authenticated(data => Ok(data)) {
    Ok(data) => data
    Err(error) => {
      @logging.log(
        @logging.Level::WARN,
        LOG_CONTEXT,
        "Could not fetch library entries with status \{status.to_kitsu()}: \{@debug.to_string(error)}.",
      )
      return Err(error)
    }
  }
  guard data.current_profile.to_option() is Some(profile) else {
    return Err(@types.Error_::Unauthorized)
  }
  let connection = profile.library.all
  let entries : Array[Entry] = []
  let nodes = connection.nodes.to_option().unwrap_or([])
  for node in nodes {
    if node.to_option() is Some(entry) && entry.media.to_option() is Some(_) {
      match entry.into_nero() {
        Ok(entry) => entries.push(entry)
        Err(error) => {
          @logging.log(
            @logging.Level::WARN,
            LOG_CONTEXT,
            "Could not read library entry \{entry.id}: \{@debug.to_string(error)}.",
          )
          return Err(error)
        }
      }
    }
  }
  if entries.length() < nodes.length() {
    @logging.log(
      @logging.Level::WARN,
      LOG_CONTEXT,
      "Skipped \{nodes.length() - entries.length()} empty library entries or entries without media.",
    )
  }
  let next = if connection.page_info.has_next_page {
    guard connection.page_info.end_cursor.to_option() is Some(next) &&
      Some(next) != cursor else {
      @logging.log(
        @logging.Level::WARN,
        LOG_CONTEXT,
        "Kitsu advertised another library page without a new continuation cursor.",
      )
      return Err(
        @types.Error_::Other(
          Some("Kitsu returned an invalid continuation cursor"),
        ),
      )
    }
    Some(next)
  } else {
    None
  }
  @logging.log(
    @logging.Level::DEBUG,
    LOG_CONTEXT,
    "Loaded \{entries.length()} library entries; more pages: \{next is Some(_)}.",
  )
  Ok({ entries, cursor: next, })
}

///|
fn find_entry(series_id : String) -> Result[LibraryEntryJson?, @types.Error_] {
  @logging.log(
    @logging.Level::DEBUG,
    LOG_CONTEXT,
    "Fetching the library entry for anime \{series_id}.",
  )
  let variables = GetEntryVariables::{ id: series_id, }
  let data : EntryDataJson = match
    @kitsu.GraphQLRequest::new(
      GET_ENTRY_QUERY + "\n" + ENTRY_FRAGMENT,
      variables,
    ).send_authenticated(data => Ok(data)) {
    Ok(data) => data
    Err(error) => {
      @logging.log(
        @logging.Level::WARN,
        LOG_CONTEXT,
        "Could not fetch the library entry for anime \{series_id}: \{@debug.to_string(error)}.",
      )
      return Err(error)
    }
  }
  guard data.current_profile.to_option() is Some(_) else {
    return Err(@types.Error_::Unauthorized)
  }
  guard data.find_anime_by_id.to_option() is Some(anime) else {
    @logging.log(
      @logging.Level::DEBUG,
      LOG_CONTEXT,
      "No anime found while looking up the library entry for \{series_id}.",
    )
    return Err(@types.Error_::NotFound)
  }
  Ok(anime.my_library_entry.to_option())
}

///|
pub fn get_entry(series_id : String) -> Result[Entry?, @types.Error_] {
  match find_entry(series_id) {
    Ok(Some(entry)) =>
      entry
      .into_nero()
      .map(entry => Some(entry))
      .map_err(error => {
        @logging.log(
          @logging.Level::WARN,
          LOG_CONTEXT,
          "Could not read library entry \{entry.id} for anime \{series_id}: \{@debug.to_string(error)}.",
        )
        error
      })
    Ok(None) => Ok(None)
    Err(error) => Err(error)
  }
}

///|
pub fn save_entry(
  series_id : String,
  status : WatchStatus,
  details : EntryDetails,
) -> Result[Entry, @types.Error_] {
  let input = match details.to_kitsu(status) {
    Ok(input) => input
    Err(error) => {
      @logging.log(
        @logging.Level::WARN,
        LOG_CONTEXT,
        "Cannot save tracking details for anime \{series_id}: \{@debug.to_string(error)}.",
      )
      return Err(error)
    }
  }
  let existing = match find_entry(series_id) {
    Ok(entry) => entry
    Err(error) => return Err(error)
  }
  let (operation, input) = match existing {
    Some(entry) => {
      @logging.log(
        @logging.Level::DEBUG,
        LOG_CONTEXT,
        "Updating library entry \{entry.id} for anime \{series_id}.",
      )
      (
        UPDATE_ENTRY_MUTATION,
        {
          ..input,
          id: Some(entry.id),
          reconsuming: entry.reconsuming && status is WATCHING,
        },
      )
    }
    None => {
      @logging.log(
        @logging.Level::DEBUG,
        LOG_CONTEXT,
        "Creating a library entry for anime \{series_id}.",
      )
      (
        CREATE_ENTRY_MUTATION,
        { ..input, media_id: Some(series_id), media_type: Some("ANIME"), },
      )
    }
  }
  let variables = MutationVariables::{ input, }
  @kitsu.GraphQLRequest::new(operation + "\n" + ENTRY_FRAGMENT, variables)
  .send_authenticated((data : MutationDataJson[LibraryEntryJson]) => {
    data.result()
  })
  .bind(entry => entry.into_nero())
  .map_err(error => {
    @logging.log(
      @logging.Level::WARN,
      LOG_CONTEXT,
      "Could not save the library entry for anime \{series_id}: \{@debug.to_string(error)}.",
    )
    error
  })
}

///|
pub fn remove_entry(series_id : String) -> Result[Unit, @types.Error_] {
  let existing = match find_entry(series_id) {
    Ok(Some(entry)) => entry
    Ok(None) => {
      @logging.log(
        @logging.Level::DEBUG,
        LOG_CONTEXT,
        "No library entry to remove for anime \{series_id}.",
      )
      return Ok(())
    }
    Err(error) => return Err(error)
  }
  @logging.log(
    @logging.Level::DEBUG,
    LOG_CONTEXT,
    "Removing library entry \{existing.id} for anime \{series_id}.",
  )
  let variables = MutationVariables::{
    input: DeleteEntryInput::{ id: existing.id, },
  }
  @kitsu.GraphQLRequest::new(REMOVE_ENTRY_MUTATION, variables)
  .send_authenticated((data : MutationDataJson[Json]) => data.result())
  .map(_ => ())
  .map_err(error => {
    @logging.log(
      @logging.Level::WARN,
      LOG_CONTEXT,
      "Could not remove library entry \{existing.id} for anime \{series_id}: \{@debug.to_string(error)}.",
    )
    error
  })
}
