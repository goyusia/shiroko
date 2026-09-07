import gleam/http
import gleam/json
import shellout
import shiroko/systemd_json
import shiroko/web
import systemd_status
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use _req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> index(req)
    ["services", unit] -> show_service(req, unit)
    _ -> wisp.not_found()
  }
}

fn index(_req: Request) -> Response {
  // Later we'll use templates, but for now a string will do.
  let body = "<h1>Hello, Joe!</h1>"

  // Return a 200 OK response with the body and a HTML content type.
  wisp.html_response(body, 200)
}

fn show_service(req: Request, unit: String) -> Response {
  use <- wisp.require_method(req, http.Get)

  let #(command, arguments) = systemd_status.unit_property_list_command(unit)
  let assert Ok(output) = shellout.command(command, arguments, in: ".", opt: [])
  let assert Ok(service) = systemd_status.parse_service(output)

  service
  |> systemd_json.service_to_json
  |> json.to_string
  |> wisp.json_response(200)
}
