import app/router
import discord_gleam
import discord_gleam/bot
import discord_gleam/discord/intents
import discord_gleam/event_handler
import discord_gleam/types/message
import dot_env as dot
import dot_env/env
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import logging
import mist
import wisp
import wisp/wisp_mist

pub fn start(wrap_reload) {
  dot.new()
  |> dot.set_debug(False)
  |> dot.load

  logging.configure()
  logging.set_level(logging.Info)

  let _ = start_webserver(wrap_reload)
  let _ = start_bot()
}

fn start_webserver(wrap_reload) {
  wisp.configure_logger()

  // Here we generate a secret key, but in a real application you would want to
  // load this from somewhere so that it is not regenerated on every restart.
  let secret_key_base = wisp.random_string(64)

  // Start the Mist web server.
  wisp_mist.handler(router.handle_request, secret_key_base)
  |> wrap_reload()
  |> mist.new
  |> mist.port(8000)
  |> mist.start
}

fn start_bot() {
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

fn simple_handler(bot, packet: event_handler.Packet) {
  case packet {
    event_handler.ReadyPacket(ready) -> {
      logging.log(
        logging.Info,
        "Bot is ready! Logged in as: " <> ready.user.username,
      )
      Nil
    }

    event_handler.MessagePacket(message) -> {
      logging.log(logging.Info, "Got message: " <> message.content)

      case message.content {
        "!ping" -> {
          let _ =
            discord_gleam.send_message(
              bot,
              message.channel_id,
              message.new("Pongfff!"),
            )

          Nil
        }

        _ -> Nil
      }
    }

    _ -> Nil
  }
}
