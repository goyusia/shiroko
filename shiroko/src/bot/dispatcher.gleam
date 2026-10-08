import bot/contract
import bot/room
import github
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
    mapping: dict.Dict(String, process.Name(room.Message)),
    factory_name: process.Name(
      factory_supervisor.Message(room.RoomStart, process.Subject(room.Message)),
    ),
    adapter: contract.Adapter,
  )
}

pub type Message {
  DispatcherText(room_id: String, text: String)
  DispatcherGitHubWebhook(
    room_id: String,
    payload: github.WebhookPayload,
    headers: github.WebhookHeaders,
  )
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  let starts_with_hash = string.starts_with(message.room_id, "#")
  let starts_with_dot = string.starts_with(message.room_id, ".")
  case starts_with_hash || starts_with_dot {
    True -> handle_channel(state, message)
    False -> handle_irrelevant(state, message)
  }
}

fn handle_channel(state: State, message: Message) {
  let #(state, room_name) = get_or_create_room(state, message.room_id)
  let room_subject = process.named_subject(room_name)

  let room_message = case message {
    DispatcherText(_, text) -> room.RoomText(text)
    DispatcherGitHubWebhook(_, payload, headers) ->
      room.RoomGitHubWebhook(payload, headers)
  }

  process.send(room_subject, room_message)
  actor.continue(state)
}

fn handle_irrelevant(state, _message) {
  actor.continue(state)
}

fn get_or_create_room(
  state: State,
  room_id: String,
) -> #(State, process.Name(room.Message)) {
  let factory_sup = factory_supervisor.get_by_name(state.factory_name)
  case dict.get(state.mapping, room_id) {
    Ok(room_name) -> #(state, room_name)
    Error(_) -> {
      let room_name = process.new_name("room:" <> room_id)
      let _ =
        factory_supervisor.start_child(
          factory_sup,
          room.RoomStart(room_id, room_name),
        )
      logging.log(logging.Info, "room.spawn: " <> room_id)

      let mapping =
        state.mapping
        |> dict.insert(room_id, room_name)
      #(State(..state, mapping:), room_name)
    }
  }
}

fn start_dispatcher(dispatcher_name, adapter_name, factory_name) {
  let initial = State(dict.new(), factory_name, adapter_name)
  actor.new(initial)
  |> actor.named(dispatcher_name)
  |> actor.on_message(handle_message)
  |> actor.start()
}

pub fn supervised(dispatcher_name, job_registry_name, adapter) {
  supervision.supervisor(fn() {
    start_supervisor(dispatcher_name, job_registry_name, adapter)
  })
}

fn start_supervisor(dispatcher_name, job_registry_name, adapter) {
  let factory_name = process.new_name("room_factory")
  let room_factory_supervisor =
    factory_supervisor.worker_child(fn(arg) {
      room.start_worker(arg, job_registry_name, adapter)
    })
    |> factory_supervisor.named(factory_name)
    |> factory_supervisor.supervised()

  let dispatcher_worker =
    supervision.worker(fn() {
      start_dispatcher(dispatcher_name, adapter, factory_name)
    })

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(room_factory_supervisor)
  |> supervisor.add(dispatcher_worker)
  |> supervisor.start()
}
