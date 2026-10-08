import bot/job_worker
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/otp/actor
import gleam/otp/factory_supervisor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleam/time/timestamp
import logging

pub type JobId =
  String

type ChildSubject =
  process.Subject(job_worker.Message)

type State {
  State(
    jobs: dict.Dict(JobId, ChildSubject),
    factory_name: process.Name(
      factory_supervisor.Message(
        job_worker.JobStart,
        process.Subject(job_worker.Message),
      ),
    ),
    registry_name: process.Name(Message),
  )
}

pub type Message {
  Spawn(fun: fn() -> Nil)
  Terminated(id: JobId)
  List
}

fn create_job_id() -> JobId {
  let now =
    timestamp.system_time()
    |> timestamp.to_unix_seconds_and_nanoseconds()

  let #(a, b) = now
  let x = { a + b } % 1_000_000
  int.to_string(x)
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Spawn(fun) -> {
      let id = create_job_id()
      let start_msg = job_worker.JobStart(id, fun)

      let supervisor = factory_supervisor.get_by_name(state.factory_name)
      let start_result = factory_supervisor.start_child(supervisor, start_msg)
      case start_result {
        Ok(started) -> {
          let registry_subject = process.named_subject(state.registry_name)
          let _watcher =
            process.spawn_unlinked(fn() {
              watch_job(started.pid, id, registry_subject)
            })

          logging.log(logging.Debug, "job.spawned: " <> id)
          let jobs =
            state.jobs
            |> dict.insert(id, started.data)
          let state = State(..state, jobs:)
          actor.continue(state)
        }
        Error(_) -> {
          logging.log(logging.Error, "Failed to spawn job")
          actor.continue(state)
        }
      }
    }
    Terminated(id) -> {
      logging.log(logging.Debug, "job.terminated: " <> id)
      let jobs = state.jobs |> dict.delete(id)
      let state = State(..state, jobs:)
      actor.continue(state)
    }
    List -> {
      actor.continue(state)
    }
  }
}

fn watch_job(
  pid: process.Pid,
  id: JobId,
  registry_subject: process.Subject(Message),
) {
  let monitor = process.monitor(pid)

  let selector =
    process.new_selector()
    |> process.select_specific_monitor(monitor, fn(down) { down })

  case process.selector_receive_forever(selector) {
    process.ProcessDown(_, _, _) ->
      process.send(registry_subject, Terminated(id))
    process.PortDown(_, _, _) -> Nil
  }
}

fn start_registry(job_registry_name, factory_name) {
  let initial =
    State(jobs: dict.new(), factory_name:, registry_name: job_registry_name)
  actor.new(initial)
  |> actor.named(job_registry_name)
  |> actor.on_message(handle_message)
  |> actor.start()
}

pub fn supervised(job_registry_name) {
  supervision.supervisor(fn() { start_supervisor(job_registry_name) })
}

fn start_supervisor(job_registry_name: process.Name(Message)) {
  let factory_name = process.new_name("job_factory")
  let job_factory_supervisor =
    factory_supervisor.worker_child(fn(arg) { job_worker.start_worker(arg) })
    |> factory_supervisor.named(factory_name)
    |> factory_supervisor.supervised()

  let job_registry_worker =
    supervision.worker(fn() { start_registry(job_registry_name, factory_name) })

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(job_factory_supervisor)
  |> supervisor.add(job_registry_worker)
  |> supervisor.start()
}
