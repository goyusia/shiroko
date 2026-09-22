import feature/contract.{type Responder}
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import shellout
import uptime/status

@external(erlang, "uptime_ffi", "uptime")
fn erlang_uptime() -> #(Int, #(Int, Int, Int))

type State =
  Nil

pub fn dispatch(
  state: State,
  tokens: List(String),
  respond: Responder,
) -> Result(State, Nil) {
  case tokens {
    ["!ops.redeploy"] -> {
      handle_redeploy(respond)
      Ok(state)
    }
    ["!ops.version"] -> {
      handle_version(respond)
      Ok(state)
    }
    ["!ops.uptime"] -> {
      handle_uptime(respond)
      Ok(state)
    }
    _ -> Error(Nil)
  }
}

fn handle_uptime(respond: Responder) {
  let #(days, #(hours, minutes, seconds)) = erlang_uptime()
  let h = hours |> int.to_string
  let m = minutes |> int.to_string |> string.pad_start(2, "0")
  let s = seconds |> int.to_string |> string.pad_start(2, "0")
  let d = days |> int.to_string
  respond(
    "shiroko uptime: " <> h <> ":" <> m <> ":" <> s <> " up " <> d <> " days",
  )
}

fn handle_version(respond: Responder) {
  let revision = status.get_commit_id()
  // TODO: markdown block 전송이 되나? multi-line text?
  ["# shiroko version", "- commit id: " <> revision]
  |> list.each(respond)
}

fn handle_redeploy(respond: Responder) {
  respond("redeploy start")
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
