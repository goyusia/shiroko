import gleam/erlang/process
import mist/reload
import shiroko/app

pub fn main() {
  let assert Ok(_) = app.start(reload.wrap)
  process.sleep_forever()
}
