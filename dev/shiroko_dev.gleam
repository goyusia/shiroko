import gleam/erlang/process
import irc
import mist/reload
import shiroko/server

pub fn main() {
  irc.start()
  // let assert Ok(_) = server.start(reload.wrap)
  // process.sleep_forever()
}
