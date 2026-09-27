import gleam/erlang/process
import gleam/otp/actor
import irc
import logging

type State =
  Nil

pub type Message {
  IrcSent(irc.Message, String)
  IrcReceived(irc.Message, String)
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  // TODO: file logging 까지 확장 계획
  case message {
    IrcSent(_, line) -> {
      logging.log(logging.Debug, "irc sent    : " <> line)
      actor.continue(state)
    }
    IrcReceived(_, line) -> {
      logging.log(logging.Debug, "irc received: " <> line)
      actor.continue(state)
    }
  }
}

pub fn start_logger(logger_name: process.Name(Message)) {
  actor.new(Nil)
  |> actor.named(logger_name)
  |> actor.on_message(handle_message)
  |> actor.start()
}
