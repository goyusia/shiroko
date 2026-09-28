import adapter/protocol
import bot/contract
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/string
import gleam/time/timestamp
import irc
import irc/message
import irc/outgoing
import irc/tag
import irc/verb
import stdx/stringx

type State {
  State(
    session_name: process.Name(protocol.SessionMessage),
    dispatcher_name: process.Name(contract.DispatcherMessage),
  )
}

type Message =
  protocol.AdapterMessage

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    protocol.IncomingIrc(message) -> handle_incoming(state, message)
    protocol.OutgoingText(channel, text) ->
      handle_outgoing_text(state, channel, text)
  }
}

fn handle_incoming(
  state: State,
  message: irc.Message,
) -> actor.Next(State, Message) {
  case message.command {
    c if c == verb.privmsg -> handle_privmsg(state, message)
    c if c == verb.invite -> handle_invite(state, message)
    _ -> {
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
  string_into_batch_loop(str, max_byte_size, [])
}

fn string_into_batch_loop(
  str: String,
  max_byte_size: Int,
  batch: List(String),
) -> List(String) {
  case stringx.split_byte_size(str, max_byte_size) {
    Ok(#(first, rest)) ->
      string_into_batch_loop(rest, max_byte_size, [first, ..batch])
    Error(_) -> list.reverse(batch)
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
  protocol.OutgoingIrcBatch(messages)
  |> process.send(session_subject, _)

  actor.continue(state)
}

fn handle_privmsg(state: State, message: irc.Message) {
  case message.params {
    [channel, text] -> {
      process.send(
        process.named_subject(state.dispatcher_name),
        contract.DispatcherText(channel, text),
      )
      actor.continue(state)
    }
    _ -> actor.continue(state)
  }
}

fn handle_invite(state: State, message: irc.Message) {
  case message.params {
    [_nickname, channel] -> {
      join(state, channel)
      actor.continue(state)
    }
    _ -> actor.continue(state)
  }
}

fn join(state: State, channel: String) {
  let session_subject = process.named_subject(state.session_name)
  outgoing.join(channel)
  |> protocol.OutgoingIrc()
  |> process.send(session_subject, _)
}

pub fn start_adapter(
  adapter_name: process.Name(protocol.AdapterMessage),
  session_name: process.Name(protocol.SessionMessage),
  dispatcher_name: process.Name(contract.DispatcherMessage),
) {
  let initial = State(session_name, dispatcher_name)
  actor.new(initial)
  |> actor.named(adapter_name)
  |> actor.on_message(handle_message)
  |> actor.start
}
