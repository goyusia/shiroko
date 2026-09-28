import irc/extension

pub fn split_multiline_concat_test() {
  let text = "123한글"
  let chunks = extension.split_multiline_concat(text, 6)
  assert chunks == ["123한", "글"]

  let text = "123한글"
  let batches = extension.split_multiline_concat(text, 5)
  assert batches == ["123", "한", "글"]

  let text = "123한글테스트"
  let batches = extension.split_multiline_concat(text, 8)
  assert batches == ["123한", "글테", "스트"]
}
