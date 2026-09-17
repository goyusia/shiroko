import gleam/erlang/atom
import gleam/erlang/process
import gleam/otp/actor

pub fn start(_type: a, _args: b) -> Result(process.Pid, actor.StartError) {
  echo "TODO: OTP Application"
  Error(actor.InitTimeout)

  // case server.start(fn(handler) { handler }) {
  //   Ok(actor.Started(pid:, ..)) -> Ok(pid)
  //   Error(error) -> Error(error)
  // }
}

pub fn stop(_state: a) -> atom.Atom {
  atom.create("ok")
}
