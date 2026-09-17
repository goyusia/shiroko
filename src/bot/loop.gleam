import bot/plugin
import gleam/bit_array
import gleam/erlang/process
import gleam/list
import gleam/result
import irc/message
import irc/reader
import mug

pub type Context {
  Context(socket: mug.Socket, buffer: BitArray, sender: plugin.Sender)
}

pub fn send_message(ctx: Context, msg: message.Message) {
  msg
  |> message.to_string()
  |> bit_array.from_string()
  |> fn(x) { bit_array.concat([x, <<"\r\n":utf8>>]) }
  |> mug.send(ctx.socket, _)
}

pub fn receive_loop(selector: process.Selector(mug.TcpMessage), ctx: Context) {
  case process.selector_receive_forever(selector) {
    mug.Packet(socket, packet) -> {
      let buffer = bit_array.append(ctx.buffer, packet)
      let #(lines, buffer) = reader.extract_lines(buffer)
      let ctx = Context(..ctx, buffer:)

      // TODO: 메세지 처리는 루프를 막으면 안된다
      list.each(lines, fn(m) { handle_line(m, ctx) })

      mug.receive_next_packet_as_message(socket)
      receive_loop(selector, ctx)
    }
    mug.SocketClosed(_socket) -> Nil
    mug.TcpError(_socket, error) -> {
      echo error
      Nil
    }
  }
}

fn handle_line(line: String, ctx: Context) {
  use msg <- result.try(message.parse(line))
  let _ = case msg.command {
    "PRIVMSG" -> plugin.dispatch(msg, ctx.sender)
    "PING" -> {
      message.Message(..msg, command: "PONG")
      |> ctx.sender.respond()
    }
    _ -> {
      echo msg
      Nil
    }
  }
  Ok(Nil)
}
