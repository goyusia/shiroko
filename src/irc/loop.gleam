import gleam/bit_array
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import irc/message
import mug

pub fn receive_loop(
  selector: process.Selector(mug.TcpMessage),
  buffer: BitArray,
) {
  case process.selector_receive_forever(selector) {
    mug.Packet(socket, packet) -> {
      let buffer = bit_array.append(buffer, packet)
      let #(lines, buffer) = frame_lines(buffer)
      let messages = lines |> list.map(message.parse)

      // TODO: 메세지 처리는 루프를 막으면 안된다
      //
      messages
      |> list.each(fn(m) {
        case m {
          Ok(m) -> handle_message(m)
          Error(err) -> {
            echo err
            Nil
          }
        }
      })

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

fn handle_message(msg: message.IrcMessage) -> Nil {
  case msg.command {
    "001" -> {
      echo msg
      Nil
    }
    _ -> {
      echo msg
      Nil
    }
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
