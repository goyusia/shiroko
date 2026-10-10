import bot/job
import clip
import clip/arg
import clip/help
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

  let fields = [Id, Room, StatusShort, Time, Command]
  let header = fields |> list.map(field_to_string) |> string.join("\t")
  let rows = runs |> list.map(fn(run) { run_to_string(run, fields) })

  [header, ..rows]
  |> string.join("\n")
  |> reporter.send()
}

fn id_arg() {
  arg.new("id")
  |> arg.int()
}

type GetInput {
  GetInput(id: Int)
}

fn get_command() {
  clip.command({
    use id <- clip.parameter
    GetInput(id)
  })
  |> clip.arg(id_arg())
  |> clip.help(help.simple("!ps.get", "get job by id"))
}

pub fn execute_get(
  args: List(String),
  job_registry: process.Subject(job.Message),
  reporter: Reporter,
) {
  case get_command() |> clip.run(args) {
    Ok(input) -> handle_get(input, job_registry, reporter)
    Error(e) -> reporter.send(e)
  }
}

fn handle_get(
  input: GetInput,
  job_registry: process.Subject(job.Message),
  reporter: Reporter,
) {
  let run = job.get_run(job_registry, input.id)

  case run {
    Ok(run) -> {
      let fields = [Id, Room, StatusLong, Time, Command]
      let lines =
        fields
        |> list.map(fn(field) {
          let name = field_to_string(field)
          let value = run_field_to_string(run, field)
          "- " <> name <> ": " <> value
        })
      let text = lines |> string.join("\n")
      reporter.send(text)
    }
    Error(_) -> reporter.send("job not found: " <> int.to_string(input.id))
  }
}

fn status_to_short_string(status: job.Status) -> String {
  case status {
    job.Starting -> "starting"
    job.Running -> "running"
    job.Finished(process.Normal) -> "exit.normal"
    job.Finished(process.Killed) -> "exit.killed"
    job.Finished(process.Abnormal(_reason)) -> "exit.abnormal"
  }
}

fn status_to_long_string(status: job.Status) -> String {
  case status {
    job.Starting -> "starting"
    job.Running -> "running"
    job.Finished(process.Normal) -> "exit.normal"
    job.Finished(process.Killed) -> "exit.killed"
    job.Finished(process.Abnormal(reason)) ->
      "exit.abnormal(" <> string.inspect(reason) <> ")"
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
  StatusShort
  StatusLong
  Time
  Room
  Command
}

fn run_field_to_string(run: job.Run, field: Field) -> String {
  case field {
    Id -> int.to_string(run.id)
    StatusShort -> status_to_short_string(run.status)
    StatusLong -> status_to_long_string(run.status)
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
    StatusShort -> "status"
    StatusLong -> "status"
    Room -> "room"
    Time -> "time"
    Command -> "command"
  }
}
