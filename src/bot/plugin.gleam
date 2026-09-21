import gleam/list
import logging
import uptime/status

pub type Reply =
  fn(String) -> Nil

pub fn dispatch(tokens: List(String), reply: Reply) {
  case tokens {
    ["!ping"] -> {
      logging.log(logging.Debug, "ping")
      handle_ping(reply)
    }
    ["!panic"] -> {
      logging.log(logging.Debug, "panic")
      handle_panic(reply)
    }
    ["!version"] -> {
      logging.log(logging.Debug, "version")
      handle_version(reply)
    }
    ["!" <> command, ..rest] -> {
      logging.log(logging.Debug, "unknown command: " <> command)
      handle_unknown(command, rest, reply)
    }
    _ -> Nil
  }
}

fn handle_ping(reply: Reply) {
  reply("pong")
}

fn handle_panic(_reply: Reply) {
  panic as "panic by irc command"
}

fn handle_version(reply: Reply) {
  let revision = status.get_commit_id()
  // TODO: markdown block 전송이 되나? multi-line text?
  ["# shiroko version", "- commit id: " <> revision]
  |> list.each(reply)
}

fn handle_unknown(command: String, _params: List(String), reply: Reply) {
  reply("unknown command: " <> command)
}
