import gleam/bit_array
import gleam/erlang/process
import gleam/list
import gleam/string
import irc/message
import irc/wire
import mug

fn send_message(socket: mug.Socket, msg: message.IrcMessage) {
  msg
  |> message.format()
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
  receive_loop(selector, <<>>)
}

fn receive_loop(selector: process.Selector(mug.TcpMessage), buffer: BitArray) {
  case process.selector_receive_forever(selector) {
    mug.Packet(socket, packet) -> {
      let buffer = bit_array.append(buffer, packet)

      let assert Ok(data) = bit_array.to_string(packet)
      let lines =
        data
        |> string.split("\r\n")
        |> list.filter(fn(line) { line != "" })

      echo "-----"
      echo lines
      echo data
      echo "-----"
      // let assert Ok(message) = message.parse(line)
      // echo message

      mug.receive_next_packet_as_message(socket)
      receive_loop(selector, buffer)
    }
    mug.SocketClosed(_socket) -> Nil
    mug.TcpError(_socket, error) -> {
      echo error
      Nil
    }
  }
}
