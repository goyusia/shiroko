import github
import gleam/http
import gleam/io
import gleam/string
import wisp.{type Request, type Response}

pub fn github(req: Request) -> Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_bit_array_body(req)

  let headers = github.headers_from_request_headers(req.headers)
  let payload = github.payload_from_request_body(body, headers.github_event)

  io.println("webhook headers: " <> string.inspect(headers))
  io.println("webhook payload: " <> string.inspect(payload))

  wisp.ok()
}
