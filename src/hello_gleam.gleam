import app/server
import gleam/erlang/process

pub fn main() {
  let assert Ok(_) = server.start(fn(h) { h })
  process.sleep_forever()
}
