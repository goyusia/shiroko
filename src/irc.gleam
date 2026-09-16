import gleam/bit_array
import gleam/erlang/process
import irc/loop
import irc/message
import irc/wire
import mug

fn send_message(socket: mug.Socket, msg: message.IrcMessage) {
  msg
  |> message.format()
  |> fn(x) { bit_array.concat([x, <<"\r\n":utf8>>]) }
  |> mug.send(socket, _)
}

pub fn start() {
  let host = "ichika"
  let port = 6667
  let nickname = "test"
  let realname = "Test 한글 User"

  let assert Ok(socket) =
    mug.new(host, port: port)
    |> mug.timeout(milliseconds: 500)
    |> mug.connect()

  let send = send_message(socket, _)
  assert wire.nick(nickname) |> send == Ok(Nil)
  assert wire.user(nickname, realname) |> send == Ok(Nil)

  let selector =
    process.new_selector()
    |> mug.select_tcp_messages(fn(msg) { msg })

  mug.receive_next_packet_as_message(socket)
  loop.receive_loop(selector, <<>>)
}
