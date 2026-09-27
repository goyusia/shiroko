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
    client_name: process.Name(protocol.ClientMessage),
  )
}

type Message =
  protocol.DispatcherMessage

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case string.starts_with(message.channel, "#") {
    True -> handle_channel(state, message)
    False -> handle_irrelevant(state, message)
  }
}

fn handle_channel(state: State, message: Message) {
  let #(state, channel_name) = get_or_create_channel(state, message.channel)
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
      let channel_name = process.new_name("channel:" <> dest)
      let _ =
        factory_supervisor.start_child(
          factory_sup,
          protocol.ChannelStart(dest, channel_name, state.client_name),
        )
      logging.log(logging.Info, "channel.spawn: " <> dest)

      let mapping =
        state.mapping
        |> dict.insert(dest, channel_name)
      #(State(..state, mapping:), channel_name)
    }
  }
}

fn start_dispatcher(dispatcher_name, client_name, factory_name) {
  let initial = State(dict.new(), factory_name, client_name)
  actor.new(initial)
  |> actor.named(dispatcher_name)
  |> actor.on_message(handle_message)
  |> actor.start()
}

pub fn supervised(dispatcher_name, client_name) {
  supervision.supervisor(fn() { start_supervisor(dispatcher_name, client_name) })
}

fn start_supervisor(dispatcher_name, client_name) {
  let factory_name = process.new_name("channel_factory")
  let channel_factory_supervisor =
    factory_supervisor.worker_child(fn(arg) {
      channel.start_worker(arg, client_name)
    })
    |> factory_supervisor.named(factory_name)
    |> factory_supervisor.supervised()

  let dispatcher_worker =
    supervision.worker(fn() {
      start_dispatcher(dispatcher_name, client_name, factory_name)
    })

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(channel_factory_supervisor)
  |> supervisor.add(dispatcher_worker)
  |> supervisor.start()
}
