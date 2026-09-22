import feature/contract.{type Reply}
import gleam/list
import uptime/status

pub fn dispatch(
  state: a,
  tokens: List(String),
  reply: Reply,
) -> Result(a, Nil) {
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
    _ -> Error(Nil)
  }
}

fn handle_ping(reply: Reply) {
  reply("pong")
}

fn handle_panic(_reply) {
  panic as "panic by irc command"
}

fn handle_version(reply: Reply) {
  let revision = status.get_commit_id()
  // TODO: markdown block 전송이 되나? multi-line text?
  ["# shiroko version", "- commit id: " <> revision]
  |> list.each(reply)
}
