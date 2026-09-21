import bot/channel
import bot/protocol
import gleam/dict
import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/factory_supervisor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision

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
  protocol.RouterMessage

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  let factory_sup = factory_supervisor.get_by_name(state.factory_name)

  let #(state, channel_name) = case dict.get(state.mapping, message.dest) {
    Ok(channel_name) -> #(state, channel_name)
    Error(_) -> {
      let name = process.new_name("channel:" <> message.dest)
      let _ =
        factory_supervisor.start_child(
          factory_sup,
          protocol.ChannelStart(message.dest, name, state.link),
        )

      let mapping =
        state.mapping
        |> dict.insert(message.dest, name)
      #(State(..state, mapping:), name)
    }
  }

  let channel_subject = process.named_subject(channel_name)
  process.send(channel_subject, protocol.ChannelMessage(text: message.text))
  actor.continue(state)
}

pub fn start_supervisor(link: protocol.Link) {
  let factory_name = process.new_name("channel_factory")
  let channel_factory_supervisor =
    factory_supervisor.worker_child(channel.start_worker)
    |> factory_supervisor.named(factory_name)
    |> factory_supervisor.supervised()

  let start_router = fn() {
    let initial = State(dict.new(), factory_name, link)
    actor.new(initial)
    |> actor.named(link.router)
    |> actor.on_message(handle_message)
    |> actor.start()
  }

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(channel_factory_supervisor)
  |> supervisor.add(supervision.worker(start_router))
  |> supervisor.start()
}
