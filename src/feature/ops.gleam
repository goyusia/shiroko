import feature/contract.{type Reply}
import gleam/list
import gleam/result
import shellout
import uptime/status

type State =
  Nil

pub fn dispatch(
  state: State,
  tokens: List(String),
  reply: Reply,
) -> Result(State, Nil) {
  case tokens {
    ["!ops.redeploy"] -> {
      handle_redeploy(reply)
      Ok(state)
    }
    ["!ops.version"] -> {
      handle_version(reply)
      Ok(state)
    }
    _ -> Ok(state)
  }
}

fn handle_version(reply: Reply) {
  let revision = status.get_commit_id()
  // TODO: markdown block 전송이 되나? multi-line text?
  ["# shiroko version", "- commit id: " <> revision]
  |> list.each(reply)
}

fn handle_redeploy(reply: Reply) {
  reply("redeploy start")
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
