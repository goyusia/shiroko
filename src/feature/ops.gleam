import feature/contract.{type Responder}
import gleam/list
import gleam/result
import shellout
import uptime/status

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
    _ -> Error(Nil)
  }
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
