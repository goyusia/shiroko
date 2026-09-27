import gleam/json
import uptime/status
import wisp.{type Request, type Response}

pub fn healthz(_req: Request) -> Response {
  let json =
    json.object([#("status", json.string("ok"))])
    |> json.to_string
  wisp.json_response(json, 200)
}

pub fn readyz(_req: Request) -> Response {
  let json =
    json.object([
      #("status", json.string("ready")),
      #("checks", json.object([#("database", json.string("ok"))])),
    ])
    |> json.to_string
  wisp.json_response(json, 200)
}

pub fn startupz(_req: Request) -> Response {
  let json =
    json.object([
      #("status", json.string("started")),
      #("phase", json.string("ready")),
    ])
    |> json.to_string
  wisp.json_response(json, 200)
}

pub fn version(_req: Request) -> Response {
  let name = "shiroko"
  let revision = status.get_commit_id()
  let version = revision
  let built_at = "TODO"

  let json =
    json.object([
      #("name", json.string(name)),
      #("version", json.string(version)),
      #("revision", json.string(revision)),
      #("built_at", json.string(built_at)),
    ])
    |> json.to_string
  wisp.json_response(json, 200)
}
