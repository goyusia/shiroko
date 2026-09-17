import gleam/dict
import gleam/option.{type Option}
import irc/message.{type Message}

pub fn pass(password: String) -> Message {
  message.Message(
    command: "PASS",
    params: [password],
    source: message.NoSource,
    tags: dict.new(),
  )
}

pub fn nick(nickname: String) -> Message {
  message.Message(
    command: "NICK",
    params: [nickname],
    source: message.NoSource,
    tags: dict.new(),
  )
}

pub fn user(username: String, realname: String) -> Message {
  message.Message(
    command: "USER",
    params: [username, "0", "*", realname],
    source: message.NoSource,
    tags: dict.new(),
  )
}

pub fn join(channel: String) -> Message {
  message.Message(
    command: "JOIN",
    params: [channel],
    source: message.NoSource,
    tags: dict.new(),
  )
}

pub fn privmsg(channel: String, text: String) -> Message {
  message.Message(
    command: "PRIVMSG",
    params: [channel, text],
    source: message.NoSource,
    tags: dict.new(),
  )
}

pub fn motd(server: Option(String)) -> Message {
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
