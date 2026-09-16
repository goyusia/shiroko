import irc/tags

pub fn unescape_value_test() {
  assert tags.unescape_value("value\\1") == "value1"
  assert tags.unescape_value("value1\\") == "value1"
}

fn assert_value(escaped: String, unescaped: String) {
  assert tags.unescape_value(escaped) == unescaped
  assert tags.escape_value(unescaped) == escaped
}

pub fn scenario_test() {
  assert_value("b\\\\and\\nk", "b\\and\nk")
  assert_value("72\\s45", "72 45")
  assert_value("gh\\:764", "gh;764")
  assert_value("value\\\\ntest", "value\\ntest")
  // TODO: 필요하면 대응
  // assert_value("\\\\\\:\\\\s\\s\\r\\n", "\\\\;\\s \r\n")
}
