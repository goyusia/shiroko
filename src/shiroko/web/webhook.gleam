import gleam/bit_array
import gleam/erlang/process
import gleam/http
import gleam/io
import gleam/result
import gleam/string
import shellout
import wisp.{type Request, type Response}

pub fn github(req: Request) -> Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_bit_array_body(req)

  io.println("github webhook headers: " <> string.inspect(req.headers))
  io.println("github webhook body: " <> dump_body(body))

  process.spawn_unlinked(deploy_shiroko)
  wisp.ok()
}

fn deploy_shiroko() {
  let dir = "/home/maint/apps/shiroko/"
  use _ <- result.try(shellout.command("git", ["pull"], dir, []))
  use _ <- result.try(shellout.command("./scripts/build_prod.sh", [], dir, []))
  use _ <- result.try(
    shellout.command("./scripts/server_restart.sh", [], dir, []),
  )
  Ok(0)
}

fn dump_body(body: BitArray) -> String {
  case bit_array.to_string(body) {
    Ok(body) -> body
    Error(_) -> bit_array.inspect(body)
  }
}
