import feature/contract.{type Reply}
import gleam/erlang/process
import gleam/list
import gleam/time/duration
import gleam/time/timestamp
import uptime/status

type State =
  Nil

pub fn dispatch(
  state: State,
  tokens: List(String),
  reply: Reply,
) -> Result(State, Nil) {
  case tokens {
    ["!ping"] -> {
      handle_ping(reply)
      Ok(state)
    }
    ["!panic"] -> {
      handle_panic(reply)
      Ok(state)
    }
    ["!version"] -> {
      handle_version(reply)
      Ok(state)
    }
    ["!delay"] -> {
      handle_delay(reply)
      Ok(state)
    }
    _ -> Error(Nil)
  }
}

fn handle_ping(reply: Reply) {
  reply("pong")
}

fn handle_panic(_reply) {
  panic as "panic by irc command"
}

fn kst_now() {
  timestamp.system_time()
  |> timestamp.to_rfc3339(duration.hours(9))
}

fn handle_delay(reply: Reply) {
  reply("delay: start " <> kst_now())

  process.spawn_unlinked(fn() {
    process.sleep(5000)
    reply("delay: end " <> kst_now())
  })
  Nil
}

fn handle_version(reply: Reply) {
  let revision = status.get_commit_id()
  // TODO: markdown block 전송이 되나? multi-line text?
  ["# shiroko version", "- commit id: " <> revision]
  |> list.each(reply)
}
