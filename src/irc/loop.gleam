import gleam/bit_array
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import irc/message
import irc/wire
import mug

pub type Context {
  Context(socket: mug.Socket)
}

pub fn send_message(ctx: Context, msg: message.IrcMessage) {
  msg
  |> message.format()
  |> fn(x) { bit_array.concat([x, <<"\r\n":utf8>>]) }
  |> mug.send(ctx.socket, _)
}

pub fn receive_loop(
  selector: process.Selector(mug.TcpMessage),
  buffer: BitArray,
) {
  case process.selector_receive_forever(selector) {
    mug.Packet(socket, packet) -> {
      let buffer = bit_array.append(buffer, packet)
      let #(lines, buffer) = frame_lines(buffer)

      // TODO: 메세지 처리는 루프를 막으면 안된다
      let ctx = Context(socket)
      list.each(lines, fn(m) { handle_line(m, ctx) })

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

fn handle_line(line: String, ctx: Context) {
  use msg <- result.try(message.parse(line))
  let _ = case msg.command {
    "PRIVMSG" -> handle_privmsg(msg, ctx)
    "PING" -> {
      let reply = message.IrcMessage(..msg, command: "PONG")
      let _ = send_message(ctx, reply)
      Nil
    }
    _ -> {
      echo msg
      Nil
    }
  }
  Ok(Nil)
}

fn handle_privmsg(msg: message.IrcMessage, ctx: Context) {
  case msg.params {
    [_, "!ping"] -> handle_ping(msg, ctx)
    [_, "!" <> _] -> handle_unknown(msg, ctx)
    _ -> Nil
  }
}

fn handle_ping(msg: message.IrcMessage, ctx: Context) {
  case msg.params {
    [channel, ..] -> {
      let reply = wire.privmsg(channel, "pong")
      let _ = send_message(ctx, reply)
      Nil
    }
    _ -> Nil
  }
}

fn handle_unknown(msg: message.IrcMessage, ctx: Context) {
  case msg.params {
    [channel, first, ..] -> {
      let text = "unknown command: " <> first
      let reply = wire.privmsg(channel, text)
      let _ = send_message(ctx, reply)
      Nil
    }
    _ -> Nil
  }
}

fn frame_lines(buffer: BitArray) -> #(List(String), BitArray) {
  let #(lines, rest) = frame_lines_inner(buffer, [])
  #(list.reverse(lines), rest)
}

fn frame_lines_inner(
  buffer: BitArray,
  acc: List(String),
) -> #(List(String), BitArray) {
  case index_of_line(buffer) {
    Some(index) -> {
      let assert Ok(bytes) = bit_array.slice(buffer, at: 0, take: index)
      let line =
        bytes
        |> bit_array.to_string()
        |> result.unwrap("")

      let remaining = bit_array.byte_size(buffer) - index - 2
      let assert Ok(rest) =
        bit_array.slice(buffer, at: index + 2, take: remaining)
      frame_lines_inner(rest, [line, ..acc])
    }
    None -> #(acc, buffer)
  }
}

fn index_of_line(buffer: BitArray) -> Option(Int) {
  index_of_line_inner(buffer, 0)
}

fn index_of_line_inner(buffer: BitArray, acc: Int) -> Option(Int) {
  case buffer {
    <<"\r\n", _rest:bytes>> -> Some(acc)
    <<_, rest:bytes>> -> index_of_line_inner(rest, acc + 1)
    _ -> None
  }
}
