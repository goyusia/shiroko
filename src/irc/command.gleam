import gleam/option.{type Option, None, Some}
import irc/message.{type IrcMessage}

pub fn pass(password: String) -> IrcMessage {
  message.IrcMessage(
    prefix: None,
    command: "PASS",
    params: [password],
    trailing: None,
  )
}

pub fn nick(nickname: String) -> IrcMessage {
  message.IrcMessage(
    prefix: None,
    command: "NICK",
    params: [nickname],
    trailing: None,
  )
}

pub fn user(username: String, realname: String) -> IrcMessage {
  message.IrcMessage(
    prefix: None,
    command: "USER",
    params: [username, "0", "*"],
    trailing: Some(realname),
  )
}

pub fn motd(server: Option(String)) -> IrcMessage {
  let params =
    server
    |> option.map(fn(s) { [s] })
    |> option.unwrap([])
  message.IrcMessage(
    prefix: None,
    command: "MOTD",
    params: params,
    trailing: None,
  )
}
