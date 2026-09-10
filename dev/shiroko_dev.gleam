import external/observer
import gleam/erlang/process

pub fn main() {
  observer.start()
  process.sleep_forever()
}
