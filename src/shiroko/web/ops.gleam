import gleam/json
import shiroko/ops
import wisp.{type Request, type Response}

pub fn redeploy(_req: Request) -> Response {
  let outcome = ops.redeploy()
  let #(status, code, message) = case outcome {
    Ok(_) -> #(200, 0, "ok")
    Error(#(code, message)) -> #(500, code, message)
  }

  let body =
    json.object([
      #("code", json.int(code)),
      #("message", json.string(message)),
    ])
    |> json.to_string

  wisp.json_response(body, status)
}
