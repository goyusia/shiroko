import bot/protocol
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/otp/actor
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
  int.to_string(s) <> int.to_string(n)
}

pub fn string_into_chunks(str: String, size: Int) -> List(String) {
  string_into_chunks_loop(str, size, [])
}

pub fn string_into_chunks_loop(
  str: String,
  size: Int,
  acc: List(String),
) -> List(String) {
  case string.length(str) {
    0 -> list.reverse(acc)
    len if len > size -> {
      let first = string.slice(str, 0, size)
      let rest = string.slice(str, size, len - size)
      string_into_chunks_loop(rest, size, [first, ..acc])
    }
    _ -> string_into_chunks_loop("", size, [str, ..acc])
  }
}

fn string_into_batch(str: String) -> List(String) {
  // https://ircv3.net/specs/extensions/multiline
  // 353 bytes -> 117 characters (utf-8 3byte 기준)
  // 반쯤 잘리는 경우는 피해야한다! 353byte 안에 넣는 식으로 자르려면 다른 방법이 필요할듯
  // 짧게해도 문제 없으니까 일단 짧게 처리
  let message_size = 80
  string_into_chunks(str, message_size)
}

fn new_privmsg_list(
  channel: String,
  content: String,
  batch_id: String,
) -> List(message.Message) {
  content
  |> string_into_batch
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
