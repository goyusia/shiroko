import bot/core
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
  core.Config(
    endpoint: core.IrcEndpoint(host: "ichika", port: 6667),
    identity: core.IrcIdentity(nickname: "shiroko", realname: "shiroko"),
    channels: ["#bot"],
  )
}
