import gleam/erlang/process
import gleam/otp/actor
import gleam/time/timestamp

pub type JobId =
  String

type State {
  State(id: JobId, spawned_at: timestamp.Timestamp)
}

pub type JobStart {
  JobStart(id: JobId, fun: fn() -> Nil)
}

pub type Message {
  Start(fun: fn() -> Nil)
}

fn handle_message(
  _state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Start(fun) -> {
      // TODO: fun은 오래 걸릴수 있다! job worker가 막히지 않는걸 기대
      fun()
      actor.stop()
    }
  }
}

pub fn start_worker(arg: JobStart) {
  actor.new_with_initialiser(1000, fn(subject) {
    process.send(subject, Start(arg.fun))

    let initial = State(arg.id, spawned_at: timestamp.system_time())
    Ok(actor.initialised(initial) |> actor.returning(subject))
  })
  |> actor.on_message(handle_message)
  |> actor.start
}
