import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gleam/string

pub type Source {
  Server(servername: String)
  User(nickname: String, user: String, host: String)
  NoSource
}

pub type Tags =
  Dict(String, String)

pub type IrcMessage {
  IrcMessage(tags: Tags, source: Source, command: String, params: List(String))
}

pub fn new(
  tags: Tags,
  source: Source,
  command: String,
  params: List(String),
) -> IrcMessage {
  IrcMessage(tags: tags, source: source, command: command, params: params)
}

pub type ParseError {
  InvalidSource
  InvalidCommand
}

pub fn parse(line: String) -> Result(IrcMessage, ParseError) {
  use #(tags, line) <- result.try(scan_tags(line))
  use #(source, line) <- result.try(scan_source(line))
  use #(command, params) <- result.try(scan_invocation(line))
  let message = IrcMessage(tags:, source:, command:, params:)
  Ok(message)
}

fn scan_tags(line: String) -> Result(#(Tags, String), ParseError) {
  case line {
    "@" <> rest -> {
      case string.split_once(rest, " ") {
        Ok(#(text, rest)) -> Ok(#(parse_tags(text), rest))
        Error(_) -> Ok(#(dict.new(), rest))
      }
    }
    _ -> Ok(#(dict.new(), line))
  }
}

fn parse_tags(text: String) -> Tags {
  string.split(text, ";")
  |> list.map(fn(item) {
    case string.split_once(item, "=") {
      Ok(#(key, value)) -> #(key, unescape_tag(value))
      Error(_) -> #(item, "")
    }
  })
  |> dict.from_list()
}

fn unescape_tag(text: String) -> String {
  text
  // |> string.replace(each: "\\n", with: "\n")
  // |> string.replace(each: "\\r", with: "\r")
  |> string.replace(each: "\\s", with: " ")
  |> string.replace(each: "\\:", with: ";")
}

fn scan_source(line: String) -> Result(#(Source, String), ParseError) {
  case line {
    ":" <> rest -> {
      case string.split_once(rest, " ") {
        Ok(#("", _)) -> Error(InvalidSource)
        Ok(#(source, rest)) -> Ok(#(Server(source), rest))
        Error(_) -> Error(InvalidSource)
      }
    }
    _ -> Ok(#(NoSource, line))
  }
}

fn scan_invocation(
  line: String,
) -> Result(#(String, List(String)), ParseError) {
  case split_invocation(line) {
    [command, ..params] -> Ok(#(command, params))
    _ -> Error(InvalidCommand)
  }
}

fn split_invocation(line: String) -> List(String) {
  case string.split_once(line, " :") {
    Ok(#(head, trailing)) -> {
      let items = split_params_fixed(head)
      list.append(items, [trailing])
    }
    Error(_) -> split_params_fixed(line)
  }
}

fn split_params_fixed(line: String) -> List(String) {
  line
  |> string.split(" ")
  |> list.filter(fn(s) { s != "" })
}

fn source_to_string(source: Source) -> String {
  case source {
    Server(servername) -> ":" <> servername
    User(nickname, user, host) -> ":" <> nickname <> "!" <> user <> "@" <> host
    NoSource -> ""
  }
}

fn is_trailing(param: String) -> Bool {
  param == "" || string.contains(param, " ") || string.starts_with(param, ":")
}

fn params_to_string(params: List(String)) -> String {
  let tokens = case list.last(params) {
    Error(_) -> []
    Ok(last) -> {
      let prefix = list.take(params, list.length(params) - 1)
      let last = case is_trailing(last) {
        True -> ":" <> last
        False -> last
      }
      list.append(prefix, [last])
    }
  }
  string.join(tokens, " ")
}

pub fn format(msg: IrcMessage) -> BitArray {
  let source = source_to_string(msg.source)
  let params = params_to_string(msg.params)

  let line =
    [source, msg.command, params]
    |> list.filter(fn(x) { x != "" })
    |> string.join(" ")
  <<line:utf8>>
}
