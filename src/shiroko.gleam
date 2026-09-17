import bot
import gleam/erlang/process
import shiroko/server

pub fn main() {
  let bot_config =
    bot.config(
      host: "ichika",
      port: 6667,
      nickname: "shiroko",
      realname: "shiroko",
      channel: "#shiroko",
    )

  let assert Ok(_) = server.start(fn(handler) { handler }, bot_config)
  process.sleep_forever()
}
