import gleam/bit_array
import irc/message.{NoSource, Server}
import irc/tags

fn assert_message(line: String, expected: message.IrcMessage) {
  assert message.parse(line) == Ok(expected)
  let assert Ok(formatted) = bit_array.to_string(message.format(expected))
  assert message.parse(formatted) == Ok(expected)
}

pub fn format_test() {
  let m =
    message.new(tags.new(), Server("hello"), "PRIVMSG", [
      "#foo",
      "bar",
      "한글 메시지",
    ])
    |> message.format()
  assert m == <<":hello PRIVMSG #foo bar :한글 메시지":utf8>>

  let m =
    message.new(tags.new(), NoSource, "PRIVMSG", ["#foo", "bar"])
    |> message.format()
  assert m == <<"PRIVMSG #foo bar":utf8>>
}

// https://github.com/ircdocs/parser-tests/blob/master/tests/msg-split.yaml
pub fn parse_simple_test() {
  let line = "foo bar baz asdf"
  let msg = message.new(tags.new(), NoSource, "foo", ["bar", "baz", "asdf"])
  assert_message(line, msg)
}

pub fn parse_with_source_test() {
  let line = ":coolguy foo bar baz asdf"
  let msg =
    message.new(tags.new(), Server("coolguy"), "foo", ["bar", "baz", "asdf"])
  assert_message(line, msg)
}

pub fn parse_with_trailing_param_test() {
  let line = "foo bar baz :asdf quux"
  let msg =
    message.new(tags.new(), NoSource, "foo", ["bar", "baz", "asdf quux"])
  assert_message(line, msg)

  let line = "foo bar baz :"
  let msg = message.new(tags.new(), NoSource, "foo", ["bar", "baz", ""])
  assert_message(line, msg)

  let line = "foo bar baz ::asdf"
  let msg = message.new(tags.new(), NoSource, "foo", ["bar", "baz", ":asdf"])
  assert_message(line, msg)
}

pub fn parse_with_source_and_trailing_param_test() {
  let line = ":coolguy foo bar baz :asdf quux"
  let msg =
    message.new(tags.new(), Server("coolguy"), "foo", [
      "bar",
      "baz",
      "asdf quux",
    ])
  assert_message(line, msg)

  let line = ":coolguy foo bar baz :  asdf quux "
  let msg =
    message.new(tags.new(), Server("coolguy"), "foo", [
      "bar",
      "baz",
      "  asdf quux ",
    ])
  assert_message(line, msg)

  let line = ":coolguy PRIVMSG bar :lol :) "
  let msg =
    message.new(tags.new(), Server("coolguy"), "PRIVMSG", ["bar", "lol :) "])
  assert_message(line, msg)

  let line = ":coolguy foo bar baz :"
  let msg =
    message.new(tags.new(), Server("coolguy"), "foo", ["bar", "baz", ""])
  assert_message(line, msg)

  let line = ":coolguy foo bar baz :  "
  let msg =
    message.new(tags.new(), Server("coolguy"), "foo", ["bar", "baz", "  "])
  assert_message(line, msg)
}

pub fn parse_with_tags_test() {
  let line = "@a=b;c=32;k;rt=ql7 foo"
  let msg =
    message.new(
      tags.from_string_tuple_list([
        #("a", "b"),
        #("c", "32"),
        #("k", ""),
        #("rt", "ql7"),
      ]),
      NoSource,
      "foo",
      [],
    )
  assert_message(line, msg)
}

pub fn parse_with_escaped_tags_test() {
  let line = "@a=b\\\\and\\nk;c=72\\s45;d=gh\\:764 foo"
  let msg =
    message.new(
      tags.from_string_tuple_list([
        #("a", "b\\and\nk"),
        #("c", "72 45"),
        #("d", "gh;764"),
      ]),
      NoSource,
      "foo",
      [],
    )
  assert_message(line, msg)
}

pub fn parse_with_tags_and_source_test() {
  let line = "@c;h=;a=b :quux ab cd"
  let msg =
    message.new(
      tags.from_string_tuple_list([#("c", ""), #("h", ""), #("a", "b")]),
      Server("quux"),
      "ab",
      ["cd"],
    )
  assert_message(line, msg)
}

pub fn parse_last_param_forms_test() {
  let line = ":src JOIN #chan"
  let msg = message.new(tags.new(), Server("src"), "JOIN", ["#chan"])
  assert_message(line, msg)

  let line = ":src JOIN :#chan"
  let msg = message.new(tags.new(), Server("src"), "JOIN", ["#chan"])
  assert_message(line, msg)

  let line = ":src AWAY"
  let msg = message.new(tags.new(), Server("src"), "AWAY", [])
  assert_message(line, msg)

  let line = ":src AWAY "
  let msg = message.new(tags.new(), Server("src"), "AWAY", [])
  assert_message(line, msg)
}

pub fn parse_tab_in_source_test() {
  let line = ":cool\tguy foo bar baz"
  let msg = message.new(tags.new(), Server("cool\tguy"), "foo", ["bar", "baz"])
  assert_message(line, msg)
}

pub fn parse_control_codes_in_source_test() {
  let line = ":coolguy!ag@net\u{03}5w\u{03}ork.admin PRIVMSG foo :bar baz"
  let msg =
    message.new(
      tags.new(),
      Server("coolguy!ag@net\u{03}5w\u{03}ork.admin"),
      "PRIVMSG",
      ["foo", "bar baz"],
    )
  assert_message(line, msg)

  let line =
    ":coolguy!~ag@n\u{02}et\u{03}05w\u{0f}ork.admin PRIVMSG foo :bar baz"
  let msg =
    message.new(
      tags.new(),
      Server("coolguy!~ag@n\u{02}et\u{03}05w\u{0f}ork.admin"),
      "PRIVMSG",
      ["foo", "bar baz"],
    )
  assert_message(line, msg)
}

pub fn parse_full_message_test() {
  let full_tags =
    tags.from_string_tuple_list([
      #("tag1", "value1"),
      #("tag2", ""),
      #("vendor1/tag3", "value2"),
      #("vendor2/tag4", ""),
    ])

  let line =
    "@tag1=value1;tag2;vendor1/tag3=value2;vendor2/tag4= :irc.example.com COMMAND param1 param2 :param3 param3"
  let msg =
    message.new(full_tags, Server("irc.example.com"), "COMMAND", [
      "param1",
      "param2",
      "param3 param3",
    ])
  assert_message(line, msg)

  let line = ":irc.example.com COMMAND param1 param2 :param3 param3"
  let msg =
    message.new(tags.new(), Server("irc.example.com"), "COMMAND", [
      "param1",
      "param2",
      "param3 param3",
    ])
  assert_message(line, msg)

  let line =
    "@tag1=value1;tag2;vendor1/tag3=value2;vendor2/tag4 COMMAND param1 param2 :param3 param3"
  let msg =
    message.new(full_tags, NoSource, "COMMAND", [
      "param1",
      "param2",
      "param3 param3",
    ])
  assert_message(line, msg)

  let line = "COMMAND"
  let msg = message.new(tags.new(), NoSource, "COMMAND", [])
  assert_message(line, msg)
}

// TODO: 필요하면 대응
// pub fn parse_yaml_encoded_tags_test() {
//   let line = "@foo=\\\\\\:\\\\s\\s\\r\\n COMMAND"
//   let msg =
//     message.new(
//       tags.from_string_tuple_list([#("foo", "\\\\;\\s \r\n")]),
//       NoSource,
//       "COMMAND",
//       [],
//     )
//   assert_message(line, msg)
// }

pub fn parse_broken_unreal_messages_test() {
  let line =
    ":gravel.mozilla.org 432  #momo :Erroneous Nickname: Illegal characters"
  let msg =
    message.new(tags.new(), Server("gravel.mozilla.org"), "432", [
      "#momo",
      "Erroneous Nickname: Illegal characters",
    ])
  assert_message(line, msg)

  let line = ":gravel.mozilla.org MODE #tckk +n "
  let msg =
    message.new(tags.new(), Server("gravel.mozilla.org"), "MODE", [
      "#tckk",
      "+n",
    ])
  assert_message(line, msg)

  let line = ":services.esper.net MODE #foo-bar +o foobar  "
  let msg =
    message.new(tags.new(), Server("services.esper.net"), "MODE", [
      "#foo-bar",
      "+o",
      "foobar",
    ])
  assert_message(line, msg)
}

pub fn parse_tag_escape_sequences_test() {
  let line = "@tag1=value\\\\ntest COMMAND"
  let msg =
    message.new(
      tags.from_string_tuple_list([#("tag1", "value\\ntest")]),
      NoSource,
      "COMMAND",
      [],
    )
  assert_message(line, msg)

  let line = "@tag1=value\\1 COMMAND"
  let msg =
    message.new(
      tags.from_string_tuple_list([#("tag1", "value1")]),
      NoSource,
      "COMMAND",
      [],
    )
  assert_message(line, msg)

  let line = "@tag1=value1\\ COMMAND"
  let msg =
    message.new(
      tags.from_string_tuple_list([#("tag1", "value1")]),
      NoSource,
      "COMMAND",
      [],
    )
  assert_message(line, msg)
}

pub fn parse_duplicate_tags_test() {
  let line = "@tag1=1;tag2=3;tag3=4;tag1=5 COMMAND"
  let msg =
    message.new(
      tags.from_string_tuple_list([
        #("tag1", "5"),
        #("tag2", "3"),
        #("tag3", "4"),
      ]),
      NoSource,
      "COMMAND",
      [],
    )
  assert_message(line, msg)

  let line = "@tag1=1;tag2=3;tag3=4;tag1=5;vendor/tag2=8 COMMAND"
  let msg =
    message.new(
      tags.from_string_tuple_list([
        #("tag1", "5"),
        #("tag2", "3"),
        #("tag3", "4"),
        #("vendor/tag2", "8"),
      ]),
      NoSource,
      "COMMAND",
      [],
    )
  assert_message(line, msg)
}

pub fn parse_mode_with_trailing_param_test() {
  let line = ":SomeOp MODE #channel :+i"
  let msg =
    message.new(tags.new(), Server("SomeOp"), "MODE", ["#channel", "+i"])
  assert_message(line, msg)

  let line = ":SomeOp MODE #channel +oo SomeUser :AnotherUser"
  let msg =
    message.new(tags.new(), Server("SomeOp"), "MODE", [
      "#channel",
      "+oo",
      "SomeUser",
      "AnotherUser",
    ])
  assert_message(line, msg)
}
