import app/server
import gleam/erlang/process
import mist/reload

pub fn main() {
  let assert Ok(_) = server.start(reload.wrap)
  process.sleep_forever()
}
