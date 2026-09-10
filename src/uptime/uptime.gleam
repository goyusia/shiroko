import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import logging

pub type HeartbeatObservation {
  Responded(status: Int, checked_at: timestamp.Timestamp)
  Unreachable(error: httpc.HttpError, checked_at: timestamp.Timestamp)
}

pub type Probe {
  Probe(name: String, url: String, interval: Int)
}

type Worker {
  Worker(probe: Probe, name: process.Name(Message))
}

pub opaque type ProbeRegistry {
  ProbeRegistry(workers: dict.Dict(String, Worker))
}

pub type State {
  State(
    subject: process.Subject(Message),
    probe: Probe,
    histories: List(HeartbeatObservation),
  )
}

pub type Message {
  GetState(Subject(State))
  CheckHttp
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    GetState(reply) -> handle_get_state(state, reply)
    CheckHttp -> handle_check_http(state)
  }
}

fn handle_check_http(state: State) -> actor.Next(State, Message) {
  let observation = case check_http(state.probe) {
    Ok(record) -> record
    Error(error) -> {
      echo error
      Unreachable(error: error, checked_at: timestamp.system_time())
    }
  }

  let histories = [observation, ..state.histories] |> list.take(10)
  let state = State(..state, histories: histories)

  process.send_after(state.subject, state.probe.interval, CheckHttp)
  actor.continue(state)
}

fn check_http(probe: Probe) {
  let assert Ok(req) = request.to(probe.url)
  use resp <- result.try(httpc.send(req))
  let now = timestamp.system_time()

  logging.log(
    logging.Info,
    "HTTP response: name="
      <> probe.name
      <> " status="
      <> int.to_string(resp.status),
  )
  let result = Responded(status: resp.status, checked_at: now)
  Ok(result)
}

fn handle_get_state(
  state: State,
  reply: Subject(State),
) -> actor.Next(State, Message) {
  actor.send(reply, state)
  actor.continue(state)
}

pub fn new(probes: List(Probe)) -> ProbeRegistry {
  let workers =
    probes
    |> list.fold(dict.new(), fn(workers, probe) {
      let worker = Worker(probe:, name: process.new_name("uptime_worker"))
      dict.insert(workers, probe.name, worker)
    })

  ProbeRegistry(workers:)
}

pub fn state(registry: ProbeRegistry, service: String) -> Result(State, Nil) {
  use worker <- result.try(dict.get(registry.workers, service))
  Ok(get_state(worker.name))
}

pub fn states(registry: ProbeRegistry) -> List(#(String, Result(State, Nil))) {
  let ProbeRegistry(workers:) = registry
  let names = dict.keys(workers)
  let requests =
    list.map(names, fn(name) {
      let reply = process.new_subject()
      process.spawn_unlinked(fn() { process.send(reply, state(registry, name)) })
      #(name, reply)
    })

  list.map(requests, fn(request) {
    let #(name, reply) = request
    let result = case process.receive(reply, 1000) {
      Ok(result) -> result
      Error(_) -> Error(Nil)
    }
    #(name, result)
  })
}

pub fn state_to_json(state: State) -> json.Json {
  let active = case state.histories {
    [Responded(..), ..] -> True
    _ -> False
  }

  json.object([
    #("name", json.string(state.probe.name)),
    #("active", json.bool(active)),
    #("history", json.array(state.histories, of: observation_to_json)),
  ])
}

fn observation_to_json(observation: HeartbeatObservation) -> json.Json {
  case observation {
    Responded(status, checked_at) ->
      json.object([
        #("active", json.bool(True)),
        #("http_status", json.int(status)),
        #(
          "checked_at",
          json.string(timestamp.to_rfc3339(checked_at, duration.seconds(0))),
        ),
      ])
    Unreachable(error, checked_at) ->
      json.object([
        #("active", json.bool(False)),
        #("error", json.string(string.inspect(error))),
        #(
          "checked_at",
          json.string(timestamp.to_rfc3339(checked_at, duration.seconds(0))),
        ),
      ])
  }
}

fn get_state(name: process.Name(Message)) -> State {
  process.named_subject(name)
  |> process.call(1000, fn(reply) { GetState(reply) })
}

pub fn supervised(registry: ProbeRegistry) {
  supervision.supervisor(fn() { start_supervisor(registry) })
}

fn start_supervisor(registry: ProbeRegistry) {
  let ProbeRegistry(workers:) = registry
  let sup =
    dict.fold(
      workers,
      from: supervisor.new(supervisor.OneForOne),
      with: fn(sup, _service, worker) {
        supervisor.add(sup, supervision.worker(fn() { start_worker(worker) }))
      },
    )
    |> supervisor.start()

  sup
}

fn start_worker(worker: Worker) {
  actor.new_with_initialiser(1000, fn(subject) {
    process.send(subject, CheckHttp)

    let initial = State(subject:, probe: worker.probe, histories: [])
    Ok(actor.initialised(initial) |> actor.returning(subject))
  })
  |> actor.named(worker.name)
  |> actor.on_message(handle_message)
  |> actor.start()
}
