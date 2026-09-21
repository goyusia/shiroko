import bot/protocol
import gleam/erlang/process
import gleam/otp/actor
import gleam/set
import irc
import irc/outgoing
import irc/verb
import logging

type State {
  State(link: protocol.Link, irrelevant_verbs: set.Set(String))
}

type Message =
  protocol.ClientMessage

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  let msg = message.message
  case msg.command, set.contains(state.irrelevant_verbs, msg.command) {
    c, _ if c == verb.privmsg -> handle_privmsg(state, msg)
    c, _ if c == verb.invite -> handle_invite(state, msg)
    _, True -> {
      logging.log(logging.Debug, "irc packet: " <> message.line)
      actor.continue(state)
    }
    _, _ -> {
      logging.log(logging.Info, "irc packet: " <> message.line)
      actor.continue(state)
    }
  }
}

fn handle_privmsg(state: State, msg: irc.Message) {
  case msg.params {
    [channel, text] -> {
      process.send(
        process.named_subject(state.link.router),
        protocol.RouterMessage(channel, text),
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

pub fn start_client(link: protocol.Link) {
  let initial = State(link, set.from_list(irrelevant_verbs))
  actor.new(initial)
  |> actor.named(link.client)
  |> actor.on_message(handle_message)
  |> actor.start
}

fn join(state: State, channel: String) {
  outgoing.join(channel)
  |> protocol.IrcOutgoing()
  |> process.send(protocol.session_subject(state.link), _)
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
