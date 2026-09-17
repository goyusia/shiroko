import bot/init.{type Config}
import bot/util
import gleam/result
import gleam/set
import irc
import irc/message
import irc/tag
import mug

pub fn login(socket: mug.Socket, config: Config) {
  let send = util.send_single(socket, _)
  assert nick_message(config.nickname) |> send == Ok(Nil)
  assert user_message(config.nickname, config.realname) |> send == Ok(Nil)
  use _ <- result.try(wait_until_welcome(socket))
  Ok(Nil)
}

fn wait_until_welcome(socket: mug.Socket) {
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

  util.receive_until_match(socket, allowlist:, denylist:)
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
