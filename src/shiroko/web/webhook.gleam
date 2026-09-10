import gleam/bit_array
import gleam/http
import gleam/io
import gleam/string
import wisp.{type Request, type Response}

pub fn github(req: Request) -> Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_bit_array_body(req)

  io.println("github webhook headers: " <> string.inspect(req.headers))
  io.println("github webhook body: " <> dump_body(body))
  wisp.ok()
}

fn dump_body(body: BitArray) -> String {
  case bit_array.to_string(body) {
    Ok(body) -> body
    Error(_) -> bit_array.inspect(body)
  }
}
