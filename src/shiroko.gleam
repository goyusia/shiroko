import logging
import dot_env as dot
import bot
import gleam/erlang/process
import shiroko/server

pub fn main() {
  logging.configure()
  logging.set_level(logging.Info)

  dot.new()
  |> dot.set_debug(False)
  |> dot.load

  let bot_config =
    bot.config(
      host: "ichika",
      port: 6667,
      nickname: "shiroko",
      realname: "shiroko",
      channel: "#bot",
    )

  let assert Ok(_) = server.start(fn(handler) { handler }, bot_config)
  process.sleep_forever()
}
