import discord_gleam
import discord_gleam/types/message
import discord_gleam/ws/packets/message as ws_message
import discord_gleam/ws/packets/ready as ws_ready
import logging

pub fn handle_discord_ready(_bot, ready: ws_ready.ReadyData) {
  logging.log(
    logging.Info,
    "Bot is ready! Logged in as: " <> ready.user.username,
  )
  Nil
}

pub fn handle_discord_message(bot, message: ws_message.MessagePacketData) {
  logging.log(logging.Info, "Got message: " <> message.content)

  case message.content {
    "!ping" -> handle_discord_ping(bot, message)
    _ -> Nil
  }
}

fn handle_discord_ping(bot, message: ws_message.MessagePacketData) {
  let _ =
    discord_gleam.send_message(bot, message.channel_id, message.new("Pong!"))

  Nil
}
