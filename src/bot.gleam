import bot/init
import bot/login
import bot/loop
import bot/plugin
import bot/util
import gleam/dict
import gleam/erlang/process
import gleam/option.{type Option}
import gleam/result
import irc
import irc/message
import logging
import mug

pub type Config =
  init.Config

pub fn config(
  host host: String,
  port port: Int,
  nickname nickname: String,
  realname realname: String,
  channel channel: String,
) {
  init.Config(host:, port:, nickname:, realname:, channel:)
}

// TODO: actor?
pub fn start(config: Config) {
  let _ =
    process.spawn_unlinked(fn() {
      case execute(config) {
        Ok(_) -> Nil
        Error(e) -> {
          logging.log(logging.Error, e)
          logging.log(logging.Error, "bot failed to start")
        }
      }
    })
}

fn execute(config: Config) {
  let assert Ok(socket) =
    mug.new(config.host, port: config.port)
    |> mug.timeout(milliseconds: 500)
    |> mug.connect()

  let sender = plugin.Sender(respond: util.send_single(socket, _))
  let ctx = loop.State(socket: socket, buffer: <<>>, sender:)
  let send = sender.respond

  use _ <- result.try(login.login(socket, config))

  assert join_message(config.channel) |> send == Ok(Nil)

  let selector =
    process.new_selector()
    |> mug.select_tcp_messages(fn(msg) { msg })

  mug.receive_next_packet_as_message(socket)
  loop.receive_loop(selector, ctx)
  Ok(Nil)
}

pub fn join_message(channel: String) -> irc.Message {
  message.Message(
    command: "JOIN",
    params: [channel],
    source: message.NoSource,
    tags: dict.new(),
  )
}

pub fn privmsg(channel: String, text: String) -> irc.Message {
  message.Message(
    command: "PRIVMSG",
    params: [channel, text],
    source: message.NoSource,
    tags: dict.new(),
  )
}

pub fn motd(server: Option(String)) -> irc.Message {
  let params =
    server
    |> option.map(fn(s) { [s] })
    |> option.unwrap([])

  message.Message(
    command: "MOTD",
    params: params,
    source: message.NoSource,
    tags: dict.new(),
  )
}
