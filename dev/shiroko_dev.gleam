import bot
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

  let bot_config =
    bot.config(
      host: "ichika",
      port: 6667,
      nickname: "shiroko_dev",
      realname: "shiroko(dev)",
      channel: "#bot_dev",
    )

  let assert Ok(_) = server.start(reload.wrap, bot_config)
  process.sleep_forever()
}
