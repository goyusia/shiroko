import bot/protocol
import gleam/bit_array
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/set
import gleam/string
import gleam/time/timestamp
import irc
import irc/message
import irc/outgoing
import irc/tag
import irc/verb
import logging

type State {
  State(
    irrelevant_verbs: set.Set(String),
    session_name: process.Name(protocol.SessionMessage),
    dispatcher_name: process.Name(protocol.DispatcherMessage),
  )
}

type Message =
  protocol.ClientMessage

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    protocol.ClientIncoming(message: msg, line:) ->
      handle_incoming(state, msg, line)
    protocol.ClientOutgoingText(channel:, text:) ->
      handle_outgoing_text(state, channel, text)
  }
}

fn handle_incoming(
  state: State,
  msg: irc.Message,
  line: String,
) -> actor.Next(State, Message) {
  case msg.command, set.contains(state.irrelevant_verbs, msg.command) {
    c, _ if c == verb.privmsg -> handle_privmsg(state, msg)
    c, _ if c == verb.invite -> handle_invite(state, msg)
    _, True -> {
      logging.log(logging.Debug, "irc packet: " <> line)
      actor.continue(state)
    }
    _, _ -> {
      logging.log(logging.Info, "irc packet: " <> line)
      actor.continue(state)
    }
  }
}

fn new_batch_id() -> String {
  let #(s, n) =
    timestamp.system_time()
    |> timestamp.to_unix_seconds_and_nanoseconds()
  let naive = s + n
  "m-" <> int.to_string(naive % 100)
}

// https://ircv3.net/specs/extensions/multiline
// 353 bytes
pub fn string_into_batch(str: String, max_byte_size: Int) -> List(String) {
  string_into_batch_loop(str, <<>>, max_byte_size, [])
}

fn string_into_batch_loop(
  str: String,
  buffer: BitArray,
  max_byte_size: Int,
  batch: List(String),
) -> List(String) {
  case string.first(str) {
    Ok(head) -> {
      let head_bit_array = bit_array.from_string(head)
      let rest = string.remove_prefix(str, head)
      case bit_array.byte_size(buffer) + bit_array.byte_size(head_bit_array) {
        size if size > max_byte_size -> {
          let line =
            buffer
            |> bit_array.to_string()
            |> result.unwrap("")
          let batch = [line, ..batch]
          string_into_batch_loop(rest, head_bit_array, max_byte_size, batch)
        }
        _ -> {
          let buffer = bit_array.append(buffer, head_bit_array)
          string_into_batch_loop(rest, buffer, max_byte_size, batch)
        }
      }
    }
    Error(_) -> {
      let line =
        buffer
        |> bit_array.to_string()
        |> result.unwrap("")
      list.reverse([line, ..batch])
    }
  }
}

fn new_privmsg_list(
  channel: String,
  content: String,
  batch_id: String,
) -> List(message.Message) {
  content
  |> string_into_batch(353)
  |> list.index_map(fn(line, index) {
    let tags =
      tag.new_tags()
      |> dict.insert("batch", tag.TagValue(batch_id))
      |> fn(tags) {
        case index {
          0 -> tags
          _ -> dict.insert(tags, "draft/multiline-concat", tag.NoTagValue)
        }
      }

    outgoing.privmsg(channel, line)
    |> message.set_tags(tags)
  })
}

fn handle_outgoing_text(state: State, channel: String, text: String) {
  let batch_id = new_batch_id()
  let batch_messages =
    text
    |> string.split("\n")
    |> list.map(new_privmsg_list(channel, _, batch_id))
    |> list.flatten()

  let batch_begin =
    message.new("BATCH", ["+" <> batch_id, "draft/multiline", channel])
  let batch_end = message.new("BATCH", ["-" <> batch_id])

  let messages = list.flatten([[batch_begin], batch_messages, [batch_end]])

  let session_subject = process.named_subject(state.session_name)
  protocol.SessionIrcOutgoingBatch(messages)
  |> process.send(session_subject, _)

  actor.continue(state)
}

fn handle_privmsg(state: State, msg: irc.Message) {
  case msg.params {
    [channel, text] -> {
      process.send(
        process.named_subject(state.dispatcher_name),
        protocol.DispatcherText(channel, text),
      )
      actor.continue(state)
    }
    _ -> actor.continue(state)
  }
}

fn handle_invite(state: State, msg: irc.Message) {
  case msg.params {
    [_nickname, channel] -> {
      join(state, channel)
      actor.continue(state)
    }
    _ -> actor.continue(state)
  }
}

pub fn start_client(
  client_name: process.Name(protocol.ClientMessage),
  session_name: process.Name(protocol.SessionMessage),
  dispatcher_name: process.Name(protocol.DispatcherMessage),
) {
  let initial =
    State(set.from_list(irrelevant_verbs), session_name, dispatcher_name)
  actor.new(initial)
  |> actor.named(client_name)
  |> actor.on_message(handle_message)
  |> actor.start
}

fn join(state: State, channel: String) {
  let session_subject = process.named_subject(state.session_name)
  outgoing.join(channel)
  |> protocol.SessionIrcOutgoing()
  |> process.send(session_subject, _)
}

const irrelevant_verbs = [
  "002",
  "003",
  "004",
  "005",
  "251",
  "252",
  "253",
  "254",
  "255",
  "265",
  "266",
  "372",
  "375",
  "376",
  "422",
]
