import gleam/erlang/process
import mist/reload
import shiroko/server

pub fn main() {
  let assert Ok(_) = server.start(reload.wrap)
  process.sleep_forever()
}
