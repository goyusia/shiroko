import bot/channel
import bot/protocol
import gleam/dict
import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/factory_supervisor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleam/string
import logging

type State {
  State(
    mapping: dict.Dict(String, process.Name(protocol.ChannelMessage)),
    factory_name: process.Name(
      factory_supervisor.Message(
        protocol.ChannelStart,
        process.Subject(protocol.ChannelMessage),
      ),
    ),
    link: protocol.Link,
  )
}

type Message =
  protocol.DispatcherMessage

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case string.starts_with(message.dest, "#") {
    True -> handle_channel(state, message)
    False -> handle_irrelevant(state, message)
  }
}

fn handle_channel(state: State, message: Message) {
  let #(state, channel_name) = get_or_create_channel(state, message.dest)
  let channel_subject = process.named_subject(channel_name)
  process.send(channel_subject, protocol.ChannelText(text: message.text))
  actor.continue(state)
}

fn handle_irrelevant(state, _message) {
  actor.continue(state)
}

fn get_or_create_channel(
  state: State,
  dest: String,
) -> #(State, process.Name(protocol.ChannelMessage)) {
  let factory_sup = factory_supervisor.get_by_name(state.factory_name)
  case dict.get(state.mapping, dest) {
    Ok(channel_name) -> #(state, channel_name)
    Error(_) -> {
      let name = process.new_name("channel:" <> dest)
      let _ =
        factory_supervisor.start_child(
          factory_sup,
          protocol.ChannelStart(dest, name, state.link),
        )
      logging.log(logging.Info, "channel.spawn: " <> dest)

      let mapping =
        state.mapping
        |> dict.insert(dest, name)
      #(State(..state, mapping:), name)
    }
  }
}

fn start_dispatcher(link: protocol.Link, factory_name) {
  let initial = State(dict.new(), factory_name, link)
  actor.new(initial)
  |> actor.named(link.dispatcher)
  |> actor.on_message(handle_message)
  |> actor.start()
}

pub fn start_supervisor(link: protocol.Link) {
  let factory_name = process.new_name("channel_factory")
  let channel_factory_supervisor =
    factory_supervisor.worker_child(channel.start_worker)
    |> factory_supervisor.named(factory_name)
    |> factory_supervisor.supervised()

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(channel_factory_supervisor)
  |> supervisor.add(
    supervision.worker(fn() { start_dispatcher(link, factory_name) }),
  )
  |> supervisor.start()
}
