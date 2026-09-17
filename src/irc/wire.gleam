import gleam/dict
import gleam/option.{type Option}
import irc/message.{type IrcMessage}

pub fn pass(password: String) -> IrcMessage {
  message.IrcMessage(
    tags: dict.new(),
    source: message.NoSource,
    command: "PASS",
    params: [password],
  )
}

pub fn nick(nickname: String) -> IrcMessage {
  message.IrcMessage(
    tags: dict.new(),
    source: message.NoSource,
    command: "NICK",
    params: [nickname],
  )
}

pub fn user(username: String, realname: String) -> IrcMessage {
  message.IrcMessage(
    tags: dict.new(),
    source: message.NoSource,
    command: "USER",
    params: [username, "0", "*", realname],
  )
}

pub fn join(channel: String) -> IrcMessage {
  message.IrcMessage(
    tags: dict.new(),
    source: message.NoSource,
    command: "JOIN",
    params: [channel],
  )
}

pub fn privmsg(channel: String, text: String) -> IrcMessage {
  message.IrcMessage(
    tags: dict.new(),
    source: message.NoSource,
    command: "PRIVMSG",
    params: [channel, text],
  )
}

pub fn motd(server: Option(String)) -> IrcMessage {
  let params =
    server
    |> option.map(fn(s) { [s] })
    |> option.unwrap([])

  message.IrcMessage(
    tags: dict.new(),
    source: message.NoSource,
    command: "MOTD",
    params: params,
  )

}
