import gleam/erlang/process
import gleam/otp/actor
import irc
import logging

type State =
  Nil

pub type Message {
  Sent(irc.Message, String)
  Received(irc.Message, String)
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  // TODO: file logging 까지 확장 계획
  case message {
    Sent(_, line) -> {
      logging.log(logging.Debug, "irc sent    : " <> line)
      actor.continue(state)
    }
    Received(_, line) -> {
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

pub fn received_fun(name: process.Name(Message)) {
  let subject = process.named_subject(name)
  fn(message: irc.Message, line: String) {
    process.send(subject, Received(message, line))
  }
}

pub fn sent_fun(name: process.Name(Message)) {
  let subject = process.named_subject(name)
  fn(message: irc.Message, line: String) {
    process.send(subject, Sent(message, line))
  }
}
