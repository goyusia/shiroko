import gleam/result
import shellout

pub fn redeploy() {
  let dir = "/home/maint/apps/shiroko/"
  use _ <- result.try(shellout.command("git", ["pull"], dir, []))
  use _ <- result.try(shellout.command("./scripts/build_prod.sh", [], dir, []))
  use _ <- result.try(
    shellout.command("./scripts/server_restart.sh", [], dir, []),
  )
  Ok(0)
}
