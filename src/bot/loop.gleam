import bot/plugin
import gleam/bit_array
import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string
import irc/message
import irc/reader
import logging
import mug

pub type State {
  State(socket: mug.Socket, buffer: BitArray, sender: plugin.Sender)
}

pub fn receive_loop(selector: process.Selector(mug.TcpMessage), state: State) {
  case process.selector_receive_forever(selector) {
    mug.Packet(socket, packet) -> {
      let buffer = bit_array.append(state.buffer, packet)
      let #(lines, buffer) = reader.extract_lines(buffer)
      let state = State(..state, buffer:)

      // TODO: 메세지 처리는 루프를 막으면 안된다
      list.each(lines, fn(m) { handle_line(m, state.sender) })

      mug.receive_next_packet_as_message(socket)
      receive_loop(selector, state)
    }
    mug.SocketClosed(_socket) -> {
      logging.log(logging.Warning, "socket closed")
      Nil
    }
    mug.TcpError(_socket, error) -> {
      logging.log(logging.Error, string.inspect(error))
      Nil
    }
  }
}

fn handle_line(line: String, sender: plugin.Sender) {
  use msg <- result.try(message.parse(line))
  let _ = case msg.command {
    "PRIVMSG" -> plugin.dispatch(msg, sender)
    "PING" -> {
      message.Message(..msg, command: "PONG")
      |> sender.respond()
    }
    _ -> {
      logging.log(logging.Debug, line)
      Ok(Nil)
    }
  }
  Ok(Nil)
}
