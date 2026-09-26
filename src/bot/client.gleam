import bot/protocol
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/set
import gleam/string
import irc
import irc/outgoing
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

fn handle_outgoing_text(state: State, channel: String, text: String) {
  let session_subject = process.named_subject(state.session_name)

  // TODO: 무식한 메세지 전송. 나중에 개선되어야한다!
  // batching, multi-line, ...
  text
  |> string.split("\n")
  |> list.filter(fn(x) { x != "" })
  |> list.map(outgoing.privmsg(channel, _))
  |> list.map(protocol.SessionIrcOutgoing)
  |> list.each(process.send(session_subject, _))

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
