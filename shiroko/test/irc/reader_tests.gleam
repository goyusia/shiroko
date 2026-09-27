import gleam/bit_array
import gleam/option
import irc/reader

pub fn find_crlf_not_exists_test() {
  let buffer = bit_array.from_string("foo")
  let index = reader.find_crlf(buffer)
  assert index == option.None
}

pub fn find_crlf_exists_test() {
  let buffer = bit_array.from_string("foo\r\nbar")
  let index = reader.find_crlf(buffer)
  assert index == option.Some(3)
}

pub fn frame_lines_no_line_test() {
  let buffer = bit_array.from_string("foo")
  let #(lines, rest) = reader.extract_lines(buffer)
  assert lines == []
  assert rest == bit_array.from_string("foo")

  let buffer = bit_array.from_string("foo\r")
  let #(lines, rest) = reader.extract_lines(buffer)
  assert lines == []
  assert rest == bit_array.from_string("foo\r")
}

pub fn extract_lines_single_line_test() {
  let buffer = bit_array.from_string("foo\r\nbar")
  let #(lines, rest) = reader.extract_lines(buffer)
  assert lines == ["foo"]
  assert rest == bit_array.from_string("bar")

  let buffer = bit_array.from_string("foo\r\n")
  let #(lines, rest) = reader.extract_lines(buffer)
  assert lines == ["foo"]
  assert rest == bit_array.from_string("")
}

pub fn extract_lines_multi_line_test() {
  let buffer = bit_array.from_string("foo\r\nbar\r\nbaz")
  let #(lines, rest) = reader.extract_lines(buffer)
  assert lines == ["foo", "bar"]
  assert rest == bit_array.from_string("baz")
}
