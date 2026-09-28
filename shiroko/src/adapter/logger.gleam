import gleam/erlang/process
import gleam/int
import gleam/otp/actor
import gleam/string
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}
import logging

type State =
  Nil

pub type Message {
  Sent(String)
  Received(String)
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  let now = timestamp.system_time()
  logging.log(logging.Debug, message_to_log(message, now))
  actor.continue(state)
}

fn timestamp_to_kst_calendar(timestamp: timestamp.Timestamp) {
  timestamp
  |> timestamp.to_calendar(duration.hours(9))
}

fn pad_int(v: Int, to: Int) -> String {
  int.to_string(v)
  |> string.pad_start(to: to, with: "0")
}

fn timestamp_to_readable_time(timestamp: Timestamp) -> String {
  let #(_, t) = timestamp_to_kst_calendar(timestamp)

  let hh = pad_int(t.hours, 2)
  let mm = pad_int(t.minutes, 2)
  let ss = pad_int(t.seconds, 2)

  let millis = t.nanoseconds / 1_000_000
  let millis = pad_int(millis, 3)

  hh <> ":" <> mm <> ":" <> ss <> "." <> millis
}

fn message_to_log(message: Message, timestamp: Timestamp) -> String {
  let time = timestamp_to_readable_time(timestamp)
  case message {
    Sent(line) -> time <> " SENT     -- " <> line
    Received(line) -> time <> " RECEIVED -- " <> line
  }
}

pub fn start_logger(logger_name: process.Name(Message)) {
  actor.new(Nil)
  |> actor.named(logger_name)
  |> actor.on_message(handle_message)
  |> actor.start()
}

pub type Logger {
  Logger(sent: fn(String) -> Nil, received: fn(String) -> Nil)
}

pub fn logger_by_name(name: process.Name(Message)) -> Logger {
  let subject = process.named_subject(name)
  let sent = fn(line: String) { process.send(subject, Sent(line)) }
  let received = fn(line: String) { process.send(subject, Received(line)) }
  Logger(sent:, received:)
}
