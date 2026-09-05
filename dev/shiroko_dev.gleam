import dot_env as dot
import gleam/erlang/process
import mist/reload
import shiroko/app

pub fn main() {
  dot.new()
  |> dot.set_debug(False)
  |> dot.load

  let assert Ok(_) = app.start(reload.wrap)
  process.sleep_forever()
}
