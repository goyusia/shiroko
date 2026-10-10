import bot/job
import clip
import feature/core.{type Reporter}
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import stdx/intx

fn list_commnad() {
  core.none_command()
}

pub fn execute_list(
  args: List(String),
  job_registry: process.Subject(job.Message),
  reporter: Reporter,
) {
  case list_commnad() |> clip.run(args) {
    Ok(_) -> handle_list(job_registry, reporter)
    Error(e) -> reporter.send(e)
  }
}

fn handle_list(job_registry: process.Subject(job.Message), reporter: Reporter) {
  let runs = job.list_runs(job_registry)

  let fields = [Id, Room, Status, Time, Command]
  let header = fields |> list.map(field_to_string) |> string.join("\t")
  let rows = runs |> list.map(fn(run) { run_to_string(run, fields) })

  [header, ..rows]
  |> string.join("\n")
  |> reporter.send()
}

fn status_to_string(status: job.Status) -> String {
  case status {
    job.Starting -> "starting"
    job.Running -> "running"
    job.Finished(reason) -> "finished(" <> string.inspect(reason) <> ")"
  }
}

fn time_to_string(run: job.Run) -> String {
  let checked_at = option.unwrap(run.finished_at, timestamp.system_time())
  let seconds =
    timestamp.difference(run.started_at, checked_at)
    |> duration.to_seconds()
    |> float.round()

  let min = { seconds / 60 } |> intx.pad_start(2, "0")
  let sec = { seconds % 60 } |> intx.pad_start(2, "0")
  min <> ":" <> sec
}

type Field {
  Id
  Status
  Time
  Room
  Command
}

fn run_field_to_string(run: job.Run, field: Field) -> String {
  case field {
    Id -> int.to_string(run.id)
    Status -> status_to_string(run.status)
    Room -> run.room_id
    Time -> time_to_string(run)
    Command -> string.join(run.argv, " ")
  }
}

fn run_to_string(run: job.Run, fields) -> String {
  fields
  |> list.map(fn(field) { run_field_to_string(run, field) })
  |> string.join("\t")
}

fn field_to_string(field: Field) -> String {
  case field {
    Id -> "id"
    Status -> "status"
    Room -> "room"
    Time -> "time"
    Command -> "command"
  }
}
