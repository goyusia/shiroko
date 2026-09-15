import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type IrcMessage {
  IrcMessage(
    prefix: Option(String),
    command: String,
    params: List(String),
    trailing: Option(String),
  )
}

pub fn format(msg: IrcMessage) -> BitArray {
  let prefix =
    msg.prefix
    |> option.map(fn(s) { [":" <> s] })
    |> option.unwrap([])

  let trailing =
    msg.trailing
    |> option.map(fn(s) { [":" <> s] })
    |> option.unwrap([])

  let list = list.flatten([prefix, [msg.command], msg.params, trailing])
  let line = string.join(list, " ") <> "\r\n"
  <<line:utf8>>
}

pub type ParseError {
  ParseError
}

pub type ScanState(a) {
  ScanState(value: a, rest: String)
}

pub fn parse(line: String) -> Result(IrcMessage, ParseError) {
  let ScanState(prefix, line) = scan_prefix(line)
  use ScanState(command, line) <- result.try(scan_command(line))
  let ScanState(params, line) = scan_params(line)
  let trailing = scan_trailing(line)
  Ok(IrcMessage(prefix, command, params, trailing))
}

pub fn scan_prefix(line: String) -> ScanState(Option(String)) {
  case string.split_once(line, " ") {
    Ok(#(":" <> s, tail)) -> ScanState(Some(s), tail)
    Ok(#(_, _tail)) -> ScanState(None, line)
    Error(_) -> ScanState(None, line)
  }
}

pub fn scan_command(line: String) -> Result(ScanState(String), ParseError) {
  case line, string.split_once(line, " ") {
    "", _ -> Error(ParseError)
    _, Ok(#(command, tail)) -> Ok(ScanState(command, tail))
    _, Error(_) -> Ok(ScanState(line, ""))
  }
}

pub fn scan_params(line: String) -> ScanState(List(String)) {
  case line {
    "" -> ScanState([], "")
    _ -> {
      let ScanState(acc, line) = parse_params_rec(line, [])
      ScanState(list.reverse(acc), line)
    }
  }
}

fn parse_params_rec(
  line: String,
  acc: List(String),
) -> ScanState(List(String)) {
  case string.split_once(line, " ") {
    Ok(#(":" <> _, _tail)) -> ScanState(acc, line)
    Ok(#(head, tail)) -> parse_params_rec(tail, [head, ..acc])
    Error(_) ->
      case line {
        ":" <> _ -> ScanState(acc, line)
        _ -> ScanState([line, ..acc], "")
      }
  }
}

pub fn scan_trailing(line: String) -> Option(String) {
  case line {
    ":" <> s -> Some(s)
    _ -> None
  }
}

pub fn pass_message(password: String) -> IrcMessage {
  IrcMessage(prefix: None, command: "PASS", params: [password], trailing: None)
}

pub fn nick_message(nickname: String) -> IrcMessage {
  IrcMessage(prefix: None, command: "NICK", params: [nickname], trailing: None)
}

pub fn user_message(username: String, realname: String) -> IrcMessage {
  IrcMessage(
    prefix: None,
    command: "USER",
    params: [username, "0", "*"],
    trailing: Some(realname),
  )
}
