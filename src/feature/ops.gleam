import feature/contract.{type Reporter}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import shellout
import uptime/status

@external(erlang, "uptime_ffi", "uptime")
fn erlang_uptime() -> #(Int, #(Int, Int, Int))

pub fn execute_uptime(argv: List(String), reporter: Reporter) {
  case contract.execute_stateless(argv, contract.none_command(), reporter) {
    Ok(_) -> handle_uptime(reporter)
    Error(_) -> Nil
  }
}

fn handle_uptime(reporter: Reporter) {
  let #(days, #(hours, minutes, seconds)) = erlang_uptime()
  let h = hours |> int.to_string
  let m = minutes |> int.to_string |> string.pad_start(2, "0")
  let s = seconds |> int.to_string |> string.pad_start(2, "0")
  let d = days |> int.to_string
  reporter.send(
    "shiroko uptime: " <> h <> ":" <> m <> ":" <> s <> " up " <> d <> " days",
  )
}

pub fn execute_version(argv: List(String), reporter: Reporter) {
  case contract.execute_stateless(argv, contract.none_command(), reporter) {
    Ok(_) -> handle_version(reporter)
    Error(_) -> Nil
  }
}

fn handle_version(reporter: Reporter) {
  let revision = status.get_commit_id()
  // TODO: markdown block 전송이 되나? multi-line text?
  ["# shiroko version", "- commit id: " <> revision]
  |> list.each(reporter.send)
}

pub fn execute_redeploy(argv: List(String), reporter: Reporter) {
  case contract.execute_stateless(argv, contract.none_command(), reporter) {
    Ok(_) -> handle_redeploy(reporter)
    Error(_) -> Nil
  }
}

fn handle_redeploy(reporter: Reporter) {
  reporter.send("redeploy start")
  let _ = redeploy()
  Nil
}

pub fn redeploy() {
  let dir = "/home/maint/apps/shiroko/"
  use _ <- result.try(shellout.command("git", ["pull"], dir, []))
  use _ <- result.try(shellout.command("./scripts/build_prod.sh", [], dir, []))
  use _ <- result.try(
    shellout.command("./scripts/server_restart.sh", [], dir, []),
  )
  Ok(0)
}
