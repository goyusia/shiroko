import gleam/int
import gleam/list
import gleam/time/timestamp
import irc/message
import irc/tag

pub fn new_batch_id() -> String {
  let #(s, n) =
    timestamp.system_time()
    |> timestamp.to_unix_seconds_and_nanoseconds()
  let naive = s + n
  "m-" <> int.to_string(naive % 100)
}

pub fn enclose_batch(
  messages: List(message.Message),
  batch_id: String,
  params: List(String),
) -> List(message.Message) {
  let batch_begin = message.new("BATCH", ["+" <> batch_id, ..params])
  let batch_end = message.new("BATCH", ["-" <> batch_id])

  let inner_list =
    messages
    |> list.map(message.insert_tag(_, "batch", tag.TagValue(batch_id)))

  []
  |> list.append([batch_begin])
  |> list.append(inner_list)
  |> list.append([batch_end])
}
