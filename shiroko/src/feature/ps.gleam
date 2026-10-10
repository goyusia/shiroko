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

  let header = "id\tcommand\tstatus\t"
  let rows =
    runs
    |> list.map(fn(run) { run_to_string(run) })

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

fn run_to_string(run: job.Run) -> String {
  let status = status_to_string(run.status)
  let command = string.join(run.argv, " ")

  let checked_at = option.unwrap(run.finished_at, timestamp.system_time())
  let seconds =
    timestamp.difference(run.started_at, checked_at)
    |> duration.to_seconds()
    |> float.round()

  let min = { seconds / 60 } |> intx.pad_start(2, "0")
  let sec = { seconds % 60 } |> intx.pad_start(2, "0")
  let time = min <> ":" <> sec

  [int.to_string(run.id), command, status, time]
  |> string.join("\t")
}
