import gleam/dict
import irc/message.{NoSource, Server}

fn no_tags() -> message.Tags {
  dict.new()
}

pub fn format_test() {
  let m =
    message.new(no_tags(), Server("hello"), "PRIVMSG", [
      "#foo",
      "bar",
      "한글 메시지",
    ])
    |> message.format()
  assert m == <<":hello PRIVMSG #foo bar :한글 메시지":utf8>>

  let m =
    message.new(no_tags(), NoSource, "PRIVMSG", ["#foo", "bar"])
    |> message.format()
  assert m == <<"PRIVMSG #foo bar":utf8>>
}

pub fn parse_simple_test() {
  let actual = message.parse("foo bar baz asdf")
  let expected = message.new(no_tags(), NoSource, "foo", ["bar", "baz", "asdf"])
  assert actual == Ok(expected)
}

pub fn parse_with_source_test() {
  let actual = message.parse(":coolguy foo bar baz asdf")
  let expected =
    message.new(no_tags(), Server("coolguy"), "foo", ["bar", "baz", "asdf"])
  assert actual == Ok(expected)
}

pub fn parse_with_trailing_param_test() {
  let actual = message.parse("foo bar baz :asdf quux")
  let expected =
    message.new(no_tags(), NoSource, "foo", ["bar", "baz", "asdf quux"])
  assert actual == Ok(expected)

  let actual = message.parse("foo bar baz :")
  let expected = message.new(no_tags(), NoSource, "foo", ["bar", "baz", ""])
  assert actual == Ok(expected)

  let actual = message.parse("foo bar baz ::asdf")
  let expected =
    message.new(no_tags(), NoSource, "foo", ["bar", "baz", ":asdf"])
  assert actual == Ok(expected)
}

pub fn parse_with_source_and_trailing_param_test() {
  let actual = message.parse(":coolguy foo bar baz :asdf quux")
  let expected =
    message.new(no_tags(), Server("coolguy"), "foo", ["bar", "baz", "asdf quux"])
  assert actual == Ok(expected)

  let actual = message.parse(":coolguy foo bar baz :  asdf quux ")
  let expected =
    message.new(no_tags(), Server("coolguy"), "foo", [
      "bar",
      "baz",
      "  asdf quux ",
    ])
  assert actual == Ok(expected)

  let actual = message.parse(":coolguy PRIVMSG bar :lol :) ")
  let expected =
    message.new(no_tags(), Server("coolguy"), "PRIVMSG", ["bar", "lol :) "])
  assert actual == Ok(expected)

  let actual = message.parse(":coolguy foo bar baz :")
  let expected =
    message.new(no_tags(), Server("coolguy"), "foo", ["bar", "baz", ""])
  assert actual == Ok(expected)

  let actual = message.parse(":coolguy foo bar baz :  ")
  let expected =
    message.new(no_tags(), Server("coolguy"), "foo", ["bar", "baz", "  "])
  assert actual == Ok(expected)
}

pub fn parse_with_tags_test() {
  let actual = message.parse("@a=b;c=32;k;rt=ql7 foo")
  let expected =
    message.new(
      dict.from_list([#("a", "b"), #("c", "32"), #("k", ""), #("rt", "ql7")]),
      NoSource,
      "foo",
      [],
    )
  assert actual == Ok(expected)
}

pub fn parse_with_escaped_tags_test() {
  let actual = message.parse("@a=b\\\\and\\nk;c=72\\s45;d=gh\\:764 foo")
  let expected =
    message.new(
      dict.from_list([#("a", "b\\and\nk"), #("c", "72 45"), #("d", "gh;764")]),
      NoSource,
      "foo",
      [],
    )
  assert actual == Ok(expected)
}

pub fn parse_with_tags_and_source_test() {
  let actual = message.parse("@c;h=;a=b :quux ab cd")
  let expected =
    message.new(
      dict.from_list([#("c", ""), #("h", ""), #("a", "b")]),
      Server("quux"),
      "ab",
      ["cd"],
    )
  assert actual == Ok(expected)
}

pub fn parse_last_param_forms_test() {
  let actual = message.parse(":src JOIN #chan")
  let expected = message.new(no_tags(), Server("src"), "JOIN", ["#chan"])
  assert actual == Ok(expected)

  let actual = message.parse(":src JOIN :#chan")
  let expected = message.new(no_tags(), Server("src"), "JOIN", ["#chan"])
  assert actual == Ok(expected)

  let actual = message.parse(":src AWAY")
  let expected = message.new(no_tags(), Server("src"), "AWAY", [])
  assert actual == Ok(expected)

  let actual = message.parse(":src AWAY ")
  let expected = message.new(no_tags(), Server("src"), "AWAY", [])
  assert actual == Ok(expected)
}

pub fn parse_tab_in_source_test() {
  let actual = message.parse(":cool\tguy foo bar baz")
  let expected =
    message.new(no_tags(), Server("cool\tguy"), "foo", ["bar", "baz"])
  assert actual == Ok(expected)
}

pub fn parse_control_codes_in_source_test() {
  let actual =
    message.parse(":coolguy!ag@net\u{03}5w\u{03}ork.admin PRIVMSG foo :bar baz")
  let expected =
    message.new(
      no_tags(),
      Server("coolguy!ag@net\u{03}5w\u{03}ork.admin"),
      "PRIVMSG",
      ["foo", "bar baz"],
    )
  assert actual == Ok(expected)

  let actual =
    message.parse(
      ":coolguy!~ag@n\u{02}et\u{03}05w\u{0f}ork.admin PRIVMSG foo :bar baz",
    )
  let expected =
    message.new(
      no_tags(),
      Server("coolguy!~ag@n\u{02}et\u{03}05w\u{0f}ork.admin"),
      "PRIVMSG",
      ["foo", "bar baz"],
    )
  assert actual == Ok(expected)
}

pub fn parse_full_message_test() {
  let full_tags =
    dict.from_list([
      #("tag1", "value1"),
      #("tag2", ""),
      #("vendor1/tag3", "value2"),
      #("vendor2/tag4", ""),
    ])

  let actual =
    message.parse(
      "@tag1=value1;tag2;vendor1/tag3=value2;vendor2/tag4= :irc.example.com COMMAND param1 param2 :param3 param3",
    )
  let expected =
    message.new(full_tags, Server("irc.example.com"), "COMMAND", [
      "param1",
      "param2",
      "param3 param3",
    ])
  assert actual == Ok(expected)

  let actual =
    message.parse(":irc.example.com COMMAND param1 param2 :param3 param3")
  let expected =
    message.new(no_tags(), Server("irc.example.com"), "COMMAND", [
      "param1",
      "param2",
      "param3 param3",
    ])
  assert actual == Ok(expected)

  let actual =
    message.parse(
      "@tag1=value1;tag2;vendor1/tag3=value2;vendor2/tag4 COMMAND param1 param2 :param3 param3",
    )
  let expected =
    message.new(full_tags, NoSource, "COMMAND", [
      "param1",
      "param2",
      "param3 param3",
    ])
  assert actual == Ok(expected)

  let actual = message.parse("COMMAND")
  let expected = message.new(no_tags(), NoSource, "COMMAND", [])
  assert actual == Ok(expected)
}

pub fn parse_yaml_encoded_tags_test() {
  let actual = message.parse("@foo=\\\\\\:\\\\s\\s\\r\\n COMMAND")
  let expected =
    message.new(
      dict.from_list([#("foo", "\\\\;\\s \r\n")]),
      NoSource,
      "COMMAND",
      [],
    )
  assert actual == Ok(expected)
}

pub fn parse_broken_unreal_messages_test() {
  let actual =
    message.parse(
      ":gravel.mozilla.org 432  #momo :Erroneous Nickname: Illegal characters",
    )
  let expected =
    message.new(no_tags(), Server("gravel.mozilla.org"), "432", [
      "#momo",
      "Erroneous Nickname: Illegal characters",
    ])
  assert actual == Ok(expected)

  let actual = message.parse(":gravel.mozilla.org MODE #tckk +n ")
  let expected =
    message.new(no_tags(), Server("gravel.mozilla.org"), "MODE", ["#tckk", "+n"])
  assert actual == Ok(expected)

  let actual = message.parse(":services.esper.net MODE #foo-bar +o foobar  ")
  let expected =
    message.new(no_tags(), Server("services.esper.net"), "MODE", [
      "#foo-bar",
      "+o",
      "foobar",
    ])
  assert actual == Ok(expected)
}

pub fn parse_tag_escape_sequences_test() {
  let actual = message.parse("@tag1=value\\\\ntest COMMAND")
  let expected =
    message.new(
      dict.from_list([#("tag1", "value\\ntest")]),
      NoSource,
      "COMMAND",
      [],
    )
  assert actual == Ok(expected)

  let actual = message.parse("@tag1=value\\1 COMMAND")
  let expected =
    message.new(dict.from_list([#("tag1", "value1")]), NoSource, "COMMAND", [])
  assert actual == Ok(expected)

  let actual = message.parse("@tag1=value1\\ COMMAND")
  let expected =
    message.new(dict.from_list([#("tag1", "value1")]), NoSource, "COMMAND", [])
  assert actual == Ok(expected)
}

pub fn parse_duplicate_tags_test() {
  let actual = message.parse("@tag1=1;tag2=3;tag3=4;tag1=5 COMMAND")
  let expected =
    message.new(
      dict.from_list([#("tag1", "5"), #("tag2", "3"), #("tag3", "4")]),
      NoSource,
      "COMMAND",
      [],
    )
  assert actual == Ok(expected)

  let actual =
    message.parse("@tag1=1;tag2=3;tag3=4;tag1=5;vendor/tag2=8 COMMAND")
  let expected =
    message.new(
      dict.from_list([
        #("tag1", "5"),
        #("tag2", "3"),
        #("tag3", "4"),
        #("vendor/tag2", "8"),
      ]),
      NoSource,
      "COMMAND",
      [],
    )
  assert actual == Ok(expected)
}

pub fn parse_mode_with_trailing_param_test() {
  let actual = message.parse(":SomeOp MODE #channel :+i")
  let expected =
    message.new(no_tags(), Server("SomeOp"), "MODE", ["#channel", "+i"])
  assert actual == Ok(expected)

  let actual = message.parse(":SomeOp MODE #channel +oo SomeUser :AnotherUser")
  let expected =
    message.new(no_tags(), Server("SomeOp"), "MODE", [
      "#channel",
      "+oo",
      "SomeUser",
      "AnotherUser",
    ])
  assert actual == Ok(expected)
}
