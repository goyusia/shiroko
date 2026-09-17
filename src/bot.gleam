import bot/init
import bot/loop
import bot/plugin
import gleam/bit_array
import gleam/dict
import gleam/erlang/process
import gleam/option.{type Option}
import irc
import irc/message
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
  let _ = process.spawn_unlinked(fn() { execute(config) })
}

fn execute(config: Config) {
  let assert Ok(socket) =
    mug.new(config.host, port: config.port)
    |> mug.timeout(milliseconds: 500)
    |> mug.connect()

  let sender =
    plugin.Sender(respond: fn(msg) {
      let _ =
        msg
        |> message.to_string()
        |> bit_array.from_string()
        |> fn(x) { bit_array.concat([x, <<"\r\n":utf8>>]) }
        |> mug.send(socket, _)
      Nil
    })

  let ctx = loop.Context(socket: socket, buffer: <<>>, sender:)
  let send = loop.send_message(ctx, _)

  assert nick(config.nickname) |> send == Ok(Nil)
  assert user(config.nickname, config.realname) |> send == Ok(Nil)
  assert join(config.channel) |> send == Ok(Nil)

  let selector =
    process.new_selector()
    |> mug.select_tcp_messages(fn(msg) { msg })

  mug.receive_next_packet_as_message(socket)
  loop.receive_loop(selector, ctx)
}

pub fn pass(password: String) -> irc.Message {
  message.Message(
    command: "PASS",
    params: [password],
    source: message.NoSource,
    tags: dict.new(),
  )
}

pub fn nick(nickname: String) -> irc.Message {
  message.Message(
    command: "NICK",
    params: [nickname],
    source: message.NoSource,
    tags: dict.new(),
  )
}

pub fn user(username: String, realname: String) -> irc.Message {
  message.Message(
    command: "USER",
    params: [username, "0", "*", realname],
    source: message.NoSource,
    tags: dict.new(),
  )
}

pub fn join(channel: String) -> irc.Message {
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
