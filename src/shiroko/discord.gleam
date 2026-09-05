import discord_gleam
import discord_gleam/bot
import discord_gleam/discord/intents
import discord_gleam/event_handler
import dot_env/env
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import shiroko/command

pub fn start_bot() {
  let token = env.get_string_or("BOT_TOKEN", "")
  let client_id = env.get_string_or("CLIENT_ID", "")
  let bot =
    bot.new(token, client_id)
    |> bot.with_intents(intents.default_with_message_intent())

  let bot =
    supervision.worker(fn() {
      discord_gleam.simple(bot, [simple_handler])
      |> discord_gleam.start()
    })

  let assert Ok(_) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(bot)
    |> supervisor.start()
}

pub fn simple_handler(bot, packet: event_handler.Packet) {
  case packet {
    event_handler.ReadyPacket(ready) -> {
      command.handle_discord_ready(bot, ready)
    }

    event_handler.MessagePacket(message) -> {
      command.handle_discord_message(bot, message)
    }

    _ -> Nil
  }
}
