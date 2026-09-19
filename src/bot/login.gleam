import bot/core.{type IrcIdentity}
import gleam/result
import gleam/set
import irc
import irc/message
import irc/tag
import mug

pub fn flow_login(socket: mug.Socket, identity: IrcIdentity) {
  let nickname = identity.nickname
  let realname = identity.realname

  let send = core.send_single(socket, _)
  use _ <- result.try(nick_message(nickname) |> send)
  use _ <- result.try(user_message(nickname, realname) |> send)
  use _ <- result.try(wait_until_welcome(socket))
  Ok(Nil)
}

pub fn wait_until_welcome(socket: mug.Socket) {
  let allowlist =
    set.from_list([
      // RPL_WELCOME
      "001",
    ])

  let denylist =
    set.from_list([
      // ERR_NICKNAMEINUSE
      "433",
    ])

  core.receive_until_match(socket, allowlist:, denylist:)
}

fn nick_message(nickname: String) -> irc.Message {
  message.new(
    command: "NICK",
    params: [nickname],
    source: message.NoSource,
    tags: tag.new_tags(),
  )
}

fn user_message(username: String, realname: String) -> irc.Message {
  message.new(
    command: "USER",
    params: [username, "0", "*", realname],
    source: message.NoSource,
    tags: tag.new_tags(),
  )
}
