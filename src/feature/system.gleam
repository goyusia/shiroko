import feature/contract.{type Responder}
import gleam/erlang/process
import gleam/time/duration
import gleam/time/timestamp

type State =
  Nil

pub fn dispatch(
  state: State,
  tokens: List(String),
  respond: Responder,
) -> Result(State, Nil) {
  case tokens {
    ["!ping"] -> {
      handle_ping(respond)
      Ok(state)
    }
    ["!panic"] -> {
      handle_panic(respond)
      Ok(state)
    }
    ["!delay"] -> {
      handle_delay(respond)
      Ok(state)
    }
    _ -> Error(Nil)
  }
}

fn handle_ping(respond: Responder) {
  respond("pong")
}

fn handle_panic(_respond) {
  panic as "panic by irc command"
}

fn kst_now() {
  timestamp.system_time()
  |> timestamp.to_rfc3339(duration.hours(9))
}

fn handle_delay(respond: Responder) {
  respond("delay: start " <> kst_now())

  process.spawn_unlinked(fn() {
    process.sleep(5000)
    respond("delay: end " <> kst_now())
  })
  Nil
}
