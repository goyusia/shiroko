import bot/client

pub fn string_into_chunks_test() {
  let text = "1234567890"
  let tokens = client.string_into_chunks(text, 3)
  assert tokens == ["123", "456", "789", "0"]

  let tokens = client.string_into_chunks(text, 10)
  assert tokens == ["1234567890"]
}
