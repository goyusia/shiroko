import gleam/option.{None, Some}
import irc/message

pub fn format_test() {
  let m =
    message.IrcMessage(
      prefix: Some("hello"),
      command: "PRIVMSG",
      params: ["#foo", "bar"],
      trailing: Some("한글 메시지"),
    )
    |> message.format()
  assert m == <<":hello PRIVMSG #foo bar :한글 메시지\r\n":utf8>>

  let m =
    message.IrcMessage(
      prefix: None,
      command: "PRIVMSG",
      params: ["#foo", "bar"],
      trailing: None,
    )
    |> message.format()
  assert m == <<"PRIVMSG #foo bar\r\n":utf8>>
}

pub fn scan_prefix_exists_test() {
  let actual = message.scan_prefix(":hello foo bar")
  let expected = message.ScanState(Some("hello"), "foo bar")
  assert actual == expected
}

pub fn scan_prefix_skip_test() {
  let actual = message.scan_prefix("foo bar")
  let expected = message.ScanState(None, "foo bar")
  assert actual == expected
}

pub fn scan_command_with_params_test() {
  let actual = message.scan_command("PRIVMSG foo bar")
  let expected = message.ScanState("PRIVMSG", "foo bar")
  assert actual == Ok(expected)
}

pub fn scan_command_without_params_test() {
  let actual = message.scan_command("PRIVMSG")
  let expected = message.ScanState("PRIVMSG", "")
  assert actual == Ok(expected)
}

pub fn scan_command_error_test() {
  let actual = message.scan_command("")
  assert actual == Error(message.ParseError)
}

pub fn scan_params_empty_test() {
  let actual = message.scan_params("")
  let expected = message.ScanState([], "")
  assert actual == expected
}

pub fn scan_params_without_trailing_test() {
  let actual = message.scan_params("foo bar")
  let expected = message.ScanState(["foo", "bar"], "")
  assert actual == expected
}

pub fn scan_params_with_trailing_test() {
  let actual = message.scan_params("foo bar :spam")
  let expected = message.ScanState(["foo", "bar"], ":spam")
  assert actual == expected
}

pub fn parse_command_only_test() {
  let actual = message.parse("PRIVMSG")
  let expected =
    message.IrcMessage(
      prefix: None,
      command: "PRIVMSG",
      params: [],
      trailing: None,
    )
  assert actual == Ok(expected)
}

pub fn parse_with_simple_test() {
  let actual = message.parse("PRIVMSG #foo bar")
  let expected =
    message.IrcMessage(
      prefix: None,
      command: "PRIVMSG",
      params: ["#foo", "bar"],
      trailing: None,
    )
  assert actual == Ok(expected)
}

pub fn parse_with_prefix_test() {
  let actual = message.parse(":hello PRIVMSG #foo bar :한글 문자열")
  let expected =
    message.IrcMessage(
      prefix: Some("hello"),
      command: "PRIVMSG",
      params: ["#foo", "bar"],
      trailing: Some("한글 문자열"),
    )
  assert actual == Ok(expected)
}
