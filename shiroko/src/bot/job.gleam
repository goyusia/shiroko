import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/time/timestamp
import logging

pub type RunId =
  Int

pub type Status {
  Starting
  Running
  Finished(reason: process.ExitReason)
}

pub type Run {
  Run(
    id: RunId,
    pid: process.Pid,
    monitor: process.Monitor,
    status: Status,
    room_id: String,
    argv: List(String),
    started_at: timestamp.Timestamp,
    finished_at: option.Option(timestamp.Timestamp),
  )
}

type State {
  State(
    inbox: process.Subject(Message),
    next_id: RunId,
    active_runs: dict.Dict(RunId, Run),
    finished_runs: List(Run),
  )
}

pub type Message {
  Submit(
    fun: fn() -> Nil,
    room_id: String,
    argv: List(String),
    reply: process.Subject(RunId),
  )
  Ready(id: RunId, start: process.Subject(Nil))
  WorkerDown(process.Down)
  ListRuns(reply: process.Subject(List(Run)))
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Submit(fun, room_id, argv, reply) -> {
      let id = state.next_id
      logging.log(logging.Debug, "job.starting: " <> int.to_string(id))

      let #(pid, monitor) = spawn_job(state.inbox, id, fun)
      let entry =
        Run(
          id:,
          pid:,
          monitor:,
          status: Starting,
          room_id:,
          argv:,
          started_at: timestamp.system_time(),
          finished_at: option.None,
        )

      let state =
        State(
          ..state,
          next_id: id + 1,
          active_runs: dict.insert(state.active_runs, id, entry),
        )

      process.send(reply, id)
      actor.continue(state)
    }
    Ready(id, start) -> {
      case dict.get(state.active_runs, id) {
        Ok(Run(status: Starting, ..) as entry) -> {
          let entry = Run(..entry, status: Running)
          let active_runs = dict.insert(state.active_runs, id, entry)

          logging.log(logging.Debug, "job.ready: " <> int.to_string(id))
          process.send(start, Nil)
          actor.continue(State(..state, active_runs: active_runs))
        }
        _ -> actor.continue(state)
      }
    }
    WorkerDown(process.ProcessDown(monitor, _pid, reason)) -> {
      let found =
        state.active_runs
        |> dict.filter(fn(_key, value) { value.monitor == monitor })
        |> dict.values()
        |> list.first()

      let state = case found {
        Ok(run) -> {
          logging.log(
            logging.Debug,
            "job.terminated: " <> int.to_string(run.id),
          )
          let active_runs = state.active_runs |> dict.delete(run.id)

          let finished_run =
            Run(
              ..run,
              status: Finished(reason),
              finished_at: option.Some(timestamp.system_time()),
            )

          // 종료 작업을 전부 들고있을 필요는 없다
          let finished_runs =
            [finished_run, ..state.finished_runs] |> list.take(5)
          State(..state, active_runs:, finished_runs:)
        }
        Error(_) -> state
      }
      actor.continue(state)
    }
    WorkerDown(process.PortDown(_monitor, _pid, _reason)) ->
      actor.continue(state)
    ListRuns(reply) -> {
      let runs =
        list.append(dict.values(state.active_runs), state.finished_runs)
      process.send(reply, runs)
      actor.continue(state)
    }
  }
}

pub fn submit(
  registry: process.Subject(Message),
  fun: fn() -> Nil,
  room_id: String,
  argv: List(String),
) -> Int {
  process.call(registry, 1000, fn(reply) { Submit(fun, room_id, argv, reply) })
}

pub fn list_runs(registry: process.Subject(Message)) -> List(Run) {
  process.call(registry, 1000, ListRuns)
}

fn spawn_job(
  registry: process.Subject(Message),
  id: Int,
  fun: fn() -> Nil,
) -> #(process.Pid, process.Monitor) {
  let pid =
    process.spawn_unlinked(fn() {
      let start = process.new_subject()
      process.send(registry, Ready(id, start))
      let Nil = process.receive_forever(start)
      fun()
    })

  let monitor = process.monitor(pid)
  #(pid, monitor)
}

pub fn start_registry(job_registry_name: process.Name(Message)) {
  actor.new_with_initialiser(1000, fn(inbox) {
    let selector =
      process.new_selector()
      |> process.select(inbox)
      |> process.select_monitors(WorkerDown)

    let initial = State(inbox, 1, active_runs: dict.new(), finished_runs: [])
    Ok(
      actor.initialised(initial)
      |> actor.selecting(selector)
      |> actor.returning(inbox),
    )
  })
  |> actor.named(job_registry_name)
  |> actor.on_message(handle_message)
  |> actor.start()
}
