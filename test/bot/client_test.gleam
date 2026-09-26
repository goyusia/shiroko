import bot/client

pub fn string_into_batch_test() {
  let text = "123한글"
  let chunks = client.string_into_batch(text, 6)
  assert chunks == ["123한", "글"]

  let text = "123한글"
  let batches = client.string_into_batch(text, 5)
  assert batches == ["123", "한", "글"]

  let text = "123한글테스트"
  let batches = client.string_into_batch(text, 8)
  assert batches == ["123한", "글테", "스트"]
}
