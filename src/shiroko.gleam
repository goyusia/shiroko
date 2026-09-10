import gleam/erlang/process
import shiroko/server

pub fn main() {
  let assert Ok(_) = server.start(fn(handler) { handler })
  process.sleep_forever()
}
