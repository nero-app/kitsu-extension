///|
pub fn list_entries(
  status : WatchStatus,
  cursor : String?,
) -> Result[EntriesPage, @types.Error_] {
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
    Err(error) => return Err(error)
  }
  guard data.current_profile.to_option() is Some(profile) else {
    return Err(@types.Error_::Unauthorized)
  }
  let connection = profile.library.all
  let entries : Array[Entry] = []
  for node in connection.nodes.to_option().unwrap_or([]) {
    if node.to_option() is Some(entry) && entry.media.to_option() is Some(_) {
      match entry.into_nero() {
        Ok(entry) => entries.push(entry)
        Err(error) => return Err(error)
      }
    }
  }
  let next = if connection.page_info.has_next_page {
    guard connection.page_info.end_cursor.to_option() is Some(next) &&
      Some(next) != cursor else {
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
  Ok({ entries, cursor: next, })
}

///|
fn find_entry(series_id : String) -> Result[LibraryEntryJson?, @types.Error_] {
  let variables = GetEntryVariables::{ id: series_id, }
  let data : EntryDataJson = match
    @kitsu.GraphQLRequest::new(
      GET_ENTRY_QUERY + "\n" + ENTRY_FRAGMENT,
      variables,
    ).send_authenticated(data => Ok(data)) {
    Ok(data) => data
    Err(error) => return Err(error)
  }
  guard data.current_profile.to_option() is Some(_) else {
    return Err(@types.Error_::Unauthorized)
  }
  guard data.find_anime_by_id.to_option() is Some(anime) else {
    return Err(@types.Error_::NotFound)
  }
  Ok(anime.my_library_entry.to_option())
}

///|
pub fn get_entry(series_id : String) -> Result[Entry?, @types.Error_] {
  match find_entry(series_id) {
    Ok(Some(entry)) => entry.into_nero().map(entry => Some(entry))
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
    Err(error) => return Err(error)
  }
  let existing = match find_entry(series_id) {
    Ok(entry) => entry
    Err(error) => return Err(error)
  }
  let (operation, input) = match existing {
    Some(entry) =>
      (
        UPDATE_ENTRY_MUTATION,
        {
          ..input,
          id: Some(entry.id),
          reconsuming: entry.reconsuming && status is WATCHING,
        },
      )
    None =>
      (
        CREATE_ENTRY_MUTATION,
        { ..input, media_id: Some(series_id), media_type: Some("ANIME"), },
      )
  }
  let variables = MutationVariables::{ input, }
  @kitsu.GraphQLRequest::new(operation + "\n" + ENTRY_FRAGMENT, variables)
  .send_authenticated((data : MutationDataJson[LibraryEntryJson]) => {
    data.result()
  })
  .bind(entry => entry.into_nero())
}

///|
pub fn remove_entry(series_id : String) -> Result[Unit, @types.Error_] {
  let existing = match find_entry(series_id) {
    Ok(Some(entry)) => entry
    Ok(None) => return Ok(())
    Err(error) => return Err(error)
  }
  let variables = MutationVariables::{
    input: DeleteEntryInput::{ id: existing.id, },
  }
  @kitsu.GraphQLRequest::new(REMOVE_ENTRY_MUTATION, variables)
  .send_authenticated((data : MutationDataJson[Json]) => data.result())
  .map(_ => ())
}
