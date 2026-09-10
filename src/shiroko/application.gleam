import gleam/erlang/atom
import gleam/erlang/process
import gleam/otp/actor
import shiroko/app

pub fn start(_type: a, _args: b) -> Result(process.Pid, actor.StartError) {
  case app.start(fn(handler) { handler }) {
    Ok(actor.Started(pid:, ..)) -> Ok(pid)
    Error(error) -> Error(error)
  }
}

pub fn stop(_state: a) -> atom.Atom {
  atom.create("ok")
}
