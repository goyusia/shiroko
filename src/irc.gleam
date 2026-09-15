import irc/command
import irc/message
import mug

pub fn start() {
  let host = "ichika"
  let port = 6667

  let assert Ok(socket) =
    mug.new(host, port: port)
    |> mug.timeout(milliseconds: 500)
    |> mug.connect()

  let nickname = "test"
  let realname = "Test 한글 User"

  let nick_msg = command.nick(nickname) |> message.format()
  echo nick_msg
  assert mug.send(socket, nick_msg) == Ok(Nil)

  let user_msg = command.user(nickname, realname) |> message.format()
  echo user_msg
  assert mug.send(socket, user_msg) == Ok(Nil)

  let assert Ok(packet) = mug.receive(socket, timeout_milliseconds: 100)
  echo packet
  Ok(Nil)
}
