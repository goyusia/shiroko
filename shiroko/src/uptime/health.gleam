import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc.{type HttpError}
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import logging

pub type Endpoint {
  Http(name: String, url: String, interval: Int)
}

pub type HttpObservation {
  Responded(status: Int, at: Timestamp)
  Unreachable(error: HttpError, at: Timestamp)
}

type Worker {
  Worker(endpoint: Endpoint, name: process.Name(Message))
}

pub opaque type EndpointRegistry {
  EndpointRegistry(workers: dict.Dict(String, Worker))
}

pub type State {
  State(
    subject: Subject(Message),
    endpoint: Endpoint,
    histories: List(HttpObservation),
  )
}

pub type Message {
  GetState(Subject(State))
  Check
  CheckFinished(Result(Response(String), HttpError))
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    GetState(reply) -> handle_get_state(state, reply)
    Check -> handle_check(state)
    CheckFinished(result) -> handle_check_finished(state, result)
  }
}

fn handle_check(state: State) -> actor.Next(State, Message) {
  let subject = state.subject
  let assert Ok(req) = request.to(state.endpoint.url)

  process.spawn_unlinked(fn() {
    // gatus는 서비스마다 시간을 다르게 설정할수 있던데 거기까지는 안해도 될듯
    let timeout = 3000
    let outcome =
      httpc.configure()
      |> httpc.timeout(timeout)
      |> httpc.dispatch(req)
    let msg = CheckFinished(outcome)
    process.send(subject, msg)
  })

  process.send_after(state.subject, state.endpoint.interval, Check)
  actor.continue(state)
}

fn handle_check_finished(
  state: State,
  outcome: Result(Response(String), HttpError),
) -> actor.Next(State, Message) {
  let State(endpoint:, ..) = state

  let now = timestamp.system_time()
  let observation = case outcome {
    Ok(resp) -> {
      logging.log(
        logging.Info,
        "HTTP response: name="
          <> endpoint.name
          <> " status="
          <> int.to_string(resp.status),
      )
      Responded(status: resp.status, at: now)
    }
    Error(error) -> {
      logging.log(
        logging.Error,
        "HTTP error: name="
          <> endpoint.name
          <> " error="
          <> string.inspect(error),
      )
      Unreachable(error: error, at: now)
    }
  }

  let histories = [observation, ..state.histories] |> list.take(10)
  let state = State(..state, histories: histories)
  actor.continue(state)
}

fn handle_get_state(
  state: State,
  reply: Subject(State),
) -> actor.Next(State, Message) {
  actor.send(reply, state)
  actor.continue(state)
}

pub fn new(endpoints: List(Endpoint)) -> EndpointRegistry {
  let workers =
    endpoints
    |> list.fold(dict.new(), fn(workers, endpoint) {
      let prefix = "uptime_worker_" <> endpoint.name
      let worker = Worker(endpoint: endpoint, name: process.new_name(prefix))
      dict.insert(workers, endpoint.name, worker)
    })

  EndpointRegistry(workers:)
}

pub fn state(
  registry: EndpointRegistry,
  service: String,
) -> Result(State, Nil) {
  use worker <- result.try(dict.get(registry.workers, service))
  Ok(get_state(worker.name))
}

pub fn states(
  registry: EndpointRegistry,
) -> List(#(String, Result(State, Nil))) {
  let EndpointRegistry(workers:) = registry
  let names = dict.keys(workers)
  let requests =
    list.map(names, fn(name) {
      let reply = process.new_subject()
      process.spawn_unlinked(fn() { process.send(reply, state(registry, name)) })
      #(name, reply)
    })

  list.map(requests, fn(request) {
    let #(name, reply) = request
    let state = case process.receive(reply, 1000) {
      Ok(result) -> result
      Error(_) -> Error(Nil)
    }
    #(name, state)
  })
}

fn get_state(name: process.Name(Message)) -> State {
  process.named_subject(name)
  |> process.call(1000, fn(reply) { GetState(reply) })
}

pub fn supervised(registry: EndpointRegistry) {
  supervision.supervisor(fn() { start_supervisor(registry) })
}

fn start_supervisor(registry: EndpointRegistry) {
  let EndpointRegistry(workers:) = registry
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
    process.send(subject, Check)

    let initial = State(subject:, endpoint: worker.endpoint, histories: [])
    Ok(actor.initialised(initial) |> actor.returning(subject))
  })
  |> actor.named(worker.name)
  |> actor.on_message(handle_message)
  |> actor.start()
}
