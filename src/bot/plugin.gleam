import bot/protocol
import gleam/list
import irc/message
import logging
import uptime/status

pub type Reply =
  fn(String) -> Result(Nil, protocol.Error)

pub fn dispatch(msg: message.Message, reply: Reply) {
  case msg.params {
    [_, "!ping", ..rest] -> {
      logging.log(logging.Debug, "ping")
      handle_ping(rest, reply)
    }
    [_, "!panic", ..rest] -> {
      logging.log(logging.Debug, "panic")
      handle_panic(rest, reply)
    }
    [_, "!version", ..rest] -> {
      logging.log(logging.Debug, "version")
      handle_version(rest, reply)
    }
    [_, "!" <> command, ..rest] -> {
      logging.log(logging.Debug, "unknown command: " <> command)
      handle_unknown(command, rest, reply)
    }
    _ -> Ok(Nil)
  }
}

fn handle_ping(_params: List(String), reply: Reply) {
  reply("pong")
}

fn handle_panic(_params: List(String), _reply: Reply) {
  panic as "panic by irc command"
}

fn handle_version(_params: List(String), reply: Reply) {
  let revision = status.get_commit_id()
  // TODO: markdown block 전송이 되나? multi-line text?
  ["# shiroko version", "- commit id: " <> revision]
  |> list.each(reply)
  Ok(Nil)
}

fn handle_unknown(command: String, _params: List(String), reply: Reply) {
  reply("unknown command: " <> command)
}
