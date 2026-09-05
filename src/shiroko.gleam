import gleam/erlang/process
import shiroko/app

pub fn main() {
  let assert Ok(_) = app.start(fn(h) { h })
  process.sleep_forever()
}
