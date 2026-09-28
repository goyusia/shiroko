import gleam/dict
import gleam/int
import gleam/list
import gleam/string
import gleam/time/timestamp
import irc/message
import irc/tag
import irc/verb
import stdx/stringx

fn new_batch_id() -> String {
  let #(s, n) =
    timestamp.system_time()
    |> timestamp.to_unix_seconds_and_nanoseconds()
  let naive = s + n
  "m-" <> int.to_string(naive % 100)
}

// https://ircv3.net/specs/extensions/multiline
// 353 bytes
pub fn split_multiline_concat(str: String, max_byte_size: Int) -> List(String) {
  split_multiline_concat_loop(str, max_byte_size, [])
}

fn split_multiline_concat_loop(
  str: String,
  max_byte_size: Int,
  acc: List(String),
) -> List(String) {
  case stringx.split_byte_size(str, max_byte_size) {
    Ok(#(first, rest)) ->
      split_multiline_concat_loop(rest, max_byte_size, [first, ..acc])
    Error(_) -> list.reverse(acc)
  }
}

fn privmsg_multiline_list(
  channel: String,
  content: String,
) -> List(message.Message) {
  content
  |> split_multiline_concat(353)
  |> list.index_map(fn(line, index) {
    let tags =
      tag.new_tags()
      |> fn(tags) {
        case index {
          0 -> tags
          _ -> dict.insert(tags, "draft/multiline-concat", tag.NoTagValue)
        }
      }

    message.new(verb.privmsg, [channel, line])
    |> message.set_tags(tags)
  })
}

fn enclose_batch(
  messages: List(message.Message),
  batch_id: String,
  channel: String,
) -> List(message.Message) {
  let batch_begin =
    message.new("BATCH", ["+" <> batch_id, "draft/multiline", channel])

  let batch_end = message.new("BATCH", ["-" <> batch_id])

  let inner_list =
    messages
    |> list.map(fn(m) { message.insert_tag(m, "batch", tag.TagValue(batch_id)) })

  []
  |> list.append([batch_begin])
  |> list.append(inner_list)
  |> list.append([batch_end])
}

pub fn privmsg_multiline(channel: String, text: String) {
  text
  |> string.split("\n")
  |> list.map(privmsg_multiline_list(channel, _))
  |> list.flatten()
  |> enclose_batch(new_batch_id(), channel)
}

fn should_use_multiline(text: String) -> Bool {
  let has_newline = string.contains(text, "\n")
  let long_text = case string.length(text) {
    x if x > 80 -> True
    _ -> False
  }
  has_newline || long_text
}

pub fn encode_privmsg(channel: String, text: String) {
  case should_use_multiline(text) {
    True -> privmsg_multiline(channel, text)
    False -> [message.new(verb.privmsg, [channel, text])]
  }
}
