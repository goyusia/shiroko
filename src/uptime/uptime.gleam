import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import logging

pub type HeartbeatObservation {
  Responded(status: Int, checked_at: timestamp.Timestamp)
  Unreachable(error: httpc.HttpError, checked_at: timestamp.Timestamp)
}

pub type State {
  State(
    subject: process.Subject(Message),
    url: String,
    duration: duration.Duration,
    histories: List(HeartbeatObservation),
  )
}

pub type Message {
  Get(Subject(State))
  CheckHttp
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Get(reply) -> handle_get(state, reply)
    CheckHttp -> handle_check_http(state)
  }
}

fn handle_check_http(state: State) -> actor.Next(State, Message) {
  let observation = case check_http(state.url) {
    Ok(record) -> record
    Error(error) -> {
      echo error
      Unreachable(error: error, checked_at: timestamp.system_time())
    }
  }

  let histories = [observation, ..state.histories] |> list.take(10)
  let state = State(..state, histories: histories)

  let delay = duration.to_milliseconds(state.duration)
  process.send_after(state.subject, delay, CheckHttp)

  actor.continue(state)
}

fn check_http(url: String) {
  let assert Ok(req) = request.to(url)
  use resp <- result.try(httpc.send(req))
  let now = timestamp.system_time()

  logging.log(
    logging.Info,
    "HTTP response: url=" <> url <> " status=" <> int.to_string(resp.status),
  )
  let result = Responded(status: resp.status, checked_at: now)
  Ok(result)
}

fn handle_get(
  state: State,
  reply: Subject(State),
) -> actor.Next(State, Message) {
  actor.send(reply, state)
  actor.continue(state)
}

pub fn start() -> Subject(Message) {
  let url = "http://192.168.219.199"
  let duration = duration.seconds(1)

  let assert Ok(actor) =
    actor.new_with_initialiser(1000, fn(subject) {
      process.send(subject, CheckHttp)

      let initial = State(subject:, url:, duration:, histories: [])
      Ok(actor.initialised(initial) |> actor.returning(subject))
    })
    |> actor.on_message(handle_message)
    |> actor.start()
  actor.data
}
