import gleam/dict.{type Dict}
import gleam/list
import gleam/string

pub type TagValue {
  TagValue(String)
  NoTagValue
}

pub type Tags =
  Dict(String, TagValue)

pub fn new() -> Tags {
  dict.new()
}

pub fn from_string_tuple_list(items: List(#(String, String))) -> Tags {
  items
  |> list.map(fn(t) {
    #(t.0, case t.1 {
      "" -> NoTagValue
      _ -> TagValue(t.1)
    })
  })
  |> dict.from_list()
}

pub fn parse_tags(text: String) -> Tags {
  string.split(text, ";")
  |> list.map(fn(item) {
    case string.split_once(item, "=") {
      Ok(#(key, "")) -> #(key, NoTagValue)
      Ok(#(key, value)) -> #(key, TagValue(unescape_value(value)))
      Error(_) -> #(item, NoTagValue)
    }
  })
  |> dict.from_list()
}

pub fn tags_to_string(tags: Tags) -> String {
  case dict.size(tags) {
    0 -> ""
    _ -> tags_to_string_exists(tags)
  }
}

fn tags_to_string_exists(tags: Tags) -> String {
  dict.to_list(tags)
  |> list.map(fn(t) {
    case t.1 {
      TagValue(value) -> t.0 <> "=" <> escape_value(value)
      NoTagValue -> t.0
    }
  })
  |> string.join(";")
  |> fn(x) { "@" <> x }
}

// https://ircv3.net/specs/extensions/message-tags.html
pub fn escape_value(text: String) -> String {
  text
  |> string.replace(each: "\\", with: "\\\\")
  |> string.replace(each: ";", with: "\\:")
  |> string.replace(each: " ", with: "\\s")
  |> string.replace(each: "\r", with: "\\r")
  |> string.replace(each: "\n", with: "\\n")
}

pub fn unescape_value(text: String) -> String {
  unescape_text(text)
}

fn unescape_text(s: String) -> String {
  case s {
    "\\" -> ""
    "\\" <> rest -> {
      case string.pop_grapheme(rest) {
        Ok(#("n", tail)) -> "\n" <> unescape_text(tail)
        Ok(#("r", tail)) -> "\r" <> unescape_text(tail)
        Ok(#("s", tail)) -> " " <> unescape_text(tail)
        Ok(#(":", tail)) -> ";" <> unescape_text(tail)
        Ok(#("\\", tail)) -> "\\" <> unescape_text(tail)
        Ok(#(a, tail)) -> a <> unescape_text(tail)
        Error(_) -> s
      }
    }
    _ -> {
      case string.pop_grapheme(s) {
        Ok(#(first, rest)) -> first <> unescape_text(rest)
        Error(_) -> s
      }
    }
  }
}
