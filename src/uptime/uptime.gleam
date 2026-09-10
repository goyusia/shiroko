import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleam/result
import gleam/time/timestamp
import logging

pub type HeartbeatObservation {
  Responded(status: Int, checked_at: timestamp.Timestamp)
  Unreachable(error: httpc.HttpError, checked_at: timestamp.Timestamp)
}

pub type Probe {
  Probe(
    name: String,
    url: String,
    interval: Int,
    worker_name: process.Name(Message),
  )
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

pub fn get_state(name: process.Name(Message)) -> State {
  process.named_subject(name)
  |> process.call(1000, fn(reply) { GetState(reply) })
}

pub fn supervised(probes: List(Probe), name: process.Name(Nil)) {
  supervision.supervisor(fn() { start_supervisor(probes, name) })
}

fn start_supervisor(probes: List(Probe), name: process.Name(Nil)) {
  let sup =
    list.fold(probes, supervisor.new(supervisor.OneForOne), fn(sup, probe) {
      supervisor.add(sup, supervision.worker(fn() { start_worker(probe) }))
    })
    |> supervisor.start()

  use started <- result.try(sup)
  let assert Ok(Nil) = process.register(started.pid, name)
  Ok(started)
}

fn start_worker(probe: Probe) {
  actor.new_with_initialiser(1000, fn(subject) {
    process.send(subject, CheckHttp)

    let initial = State(subject:, probe:, histories: [])
    Ok(actor.initialised(initial) |> actor.returning(subject))
  })
  |> actor.named(probe.worker_name)
  |> actor.on_message(handle_message)
  |> actor.start()
}
