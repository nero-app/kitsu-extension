///|
type VideoResolver = (String, String) -> Result[
  Array[@types.Video],
  @types.Error_,
]

///|
let video_resolver : Ref[VideoResolver] = { val: (_, _) => Ok([]), }

///|
pub fn get_series_videos(
  series_id : String,
  episode_id : String,
) -> Result[Array[@types.Video], @types.Error_] {
  (video_resolver.val)(series_id, episode_id)
}
