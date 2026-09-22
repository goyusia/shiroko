import feature/ops
import gleam/bit_array
import gleam/erlang/process
import gleam/http
import gleam/io
import gleam/string
import wisp.{type Request, type Response}

// TODO: 검증해서 의미있는 수정만 재배포하는게 나중에 필요할지도?
pub fn github(req: Request) -> Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_bit_array_body(req)

  io.println("github webhook headers: " <> string.inspect(req.headers))
  io.println("github webhook body: " <> dump_body(body))

  process.spawn_unlinked(ops.redeploy)
  wisp.ok()
}

fn dump_body(body: BitArray) -> String {
  case bit_array.to_string(body) {
    Ok(body) -> body
    Error(_) -> bit_array.inspect(body)
  }
}
