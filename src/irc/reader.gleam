import gleam/option.{type Option, None, Some}
import gleam/bit_array
import gleam/list

pub fn extract_lines(buffer: BitArray) -> #(List(String), BitArray) {
  let #(lines, rest) = extract_lines_loop(buffer, [])
  #(list.reverse(lines), rest)
}

fn extract_lines_loop(
  buffer: BitArray,
  acc: List(String),
) -> #(List(String), BitArray) {
  case find_crlf(buffer) {
    Some(index) -> {
      let assert Ok(bytes) = bit_array.slice(buffer, at: 0, take: index)
      let assert Ok(line) = bit_array.to_string(bytes)

      let remaining = bit_array.byte_size(buffer) - index - 2
      let assert Ok(rest) =
        bit_array.slice(buffer, at: index + 2, take: remaining)
      extract_lines_loop(rest, [line, ..acc])
    }
    None -> #(acc, buffer)
  }
}

pub fn find_crlf(buffer: BitArray) -> Option(Int) {
  find_crlf_loop(buffer, 0)
}

fn find_crlf_loop(buffer: BitArray, offset: Int) -> Option(Int) {
  case buffer {
    <<"\r\n", _rest:bytes>> -> Some(offset)
    <<_, rest:bytes>> -> find_crlf_loop(rest, offset + 1)
    _ -> None
  }
}
