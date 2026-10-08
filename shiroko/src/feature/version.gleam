import child_process
import clip
import feature/core.{type Reporter}
import gleam/string

pub fn get_commit_id() -> String {
  let assert Ok(revision) = child_process.shell("git rev-parse HEAD")
  revision
}

pub fn execute_version(argv: List(String), reporter: Reporter) {
  case core.none_command() |> clip.run(argv) {
    Ok(_) -> handle_version(reporter)
    Error(e) -> reporter.send(e)
  }
}

fn handle_version(reporter: Reporter) {
  let revision = get_commit_id()
  ["# shiroko version", "- commit id: " <> revision]
  |> string.join("\n")
  |> reporter.send
}
