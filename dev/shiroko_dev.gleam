import bot/protocol
import dot_env as dot
import gleam/erlang/process
import logging
import mist/reload
import shiroko/server

pub fn main() {
  logging.configure()
  logging.set_level(logging.Debug)

  dot.new()
  |> dot.set_debug(False)
  |> dot.load

  let bot_config = bot_config()

  let assert Ok(_) = server.start(reload.wrap, bot_config)
  process.sleep_forever()
}

fn bot_config() {
  protocol.Config(
    endpoint: protocol.IrcEndpoint(host: "ichika", port: 6667),
    identity: protocol.IrcIdentity(
      nickname: "shiroko_dev",
      realname: "shiroko(dev)",
    ),
    channels: ["#bot_dev"],
  )
}
