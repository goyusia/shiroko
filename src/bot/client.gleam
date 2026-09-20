import bot/core
import bot/plugin
import gleam/erlang/process
import gleam/otp/actor
import irc
import irc/outgoing
import irc/verb
import logging

type State {
  State(link: core.Link)
}

type Message =
  core.ClientMessage

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  let msg = message.message
  case msg.command {
    c if c == verb.privmsg -> handle_privmsg(state, msg)
    c if c == verb.invite -> handle_invite(state, msg)
    _ -> {
      logging.log(logging.Info, "irc packet: " <> message.line)
      actor.continue(state)
    }
  }
}

fn handle_privmsg(state: State, msg: irc.Message) {
  case msg.params {
    [dest, ..] -> {
      let reply: plugin.Reply = fn(line) {
        let _ =
          outgoing.privmsg(dest, line)
          |> core.IrcOutgoing()
          |> process.send(core.session_subject(state.link), _)
        Ok(Nil)
      }
      let _ = plugin.dispatch(msg, reply)
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

pub fn start_supervisor(link: core.Link) {
  let initial = State(link)
  actor.new(initial)
  |> actor.named(link.client)
  |> actor.on_message(handle_message)
  |> actor.start
}

fn join(state: State, channel: String) {
  outgoing.join(channel)
  |> core.IrcOutgoing()
  |> process.send(core.session_subject(state.link), _)
}
