import bot/core
import gleam/otp/actor
import irc/outgoing
import mug

type State =
  Int

type Message =
  String

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  echo message
  actor.continue(state)
}

pub fn start_supervisor() {
  actor.new(0)
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn join(socket: mug.Socket, channel: String) {
  outgoing.join(channel)
  |> core.send_single(socket, _)
}
