import bot/protocol
import dot_env as dot
import gleam/erlang/process
import logging
import shiroko/server

pub fn main() {
  logging.configure()
  logging.set_level(logging.Info)

  dot.new()
  |> dot.set_debug(False)
  |> dot.load

  let bot_config = bot_config()

  let assert Ok(_) = server.start(fn(handler) { handler }, bot_config)
  process.sleep_forever()
}

fn bot_config() {
  protocol.Config(
    endpoint: protocol.IrcEndpoint(host: "ichika", port: 6667),
    identity: protocol.IrcIdentity(nickname: "shiroko", realname: "shiroko"),
    channels: ["#bot"],
  )
}
