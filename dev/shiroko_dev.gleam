import bot
import gleam/erlang/process
import mist/reload
import shiroko/server

pub fn main() {
  let bot_config =
    bot.config(
      host: "ichika",
      port: 6667,
      nickname: "shiroko_dev",
      realname: "shiroko-dev",
      channel: "#shiroko_dev",
    )

  let assert Ok(_) = server.start(reload.wrap, bot_config)
  process.sleep_forever()
}
