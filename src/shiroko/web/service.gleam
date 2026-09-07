import gleam/http
import gleam/json
import gleam/list
import lustre/attribute
import lustre/element
import lustre/element/html.{html}
import shiroko/http_json
import shiroko/service/systemd
import shiroko/service/systemd_json
import systemd_status
import wisp.{type Request, type Response}

pub fn view_list_service(_req: Request) -> Response {
  let units = [
    "shiroko",
    "dagu",
    "gatus",
    "hister",
    "monit",
    "nats-server",
    "pihole-FTL",
    "tailscaled",
    "whook",
  ]
  let elements =
    units
    |> list.map(fn(unit: String) {
      let link = "/services/" <> unit
      html.li([], [html.a([attribute.href(link)], [html.text(unit)])])
    })

  let html =
    html([], [
      html.body([], [
        html.h1([], [html.text("systemd services")]),
        html.ul([], elements),
      ]),
    ])
    |> element.to_document_string
  wisp.html_response(html, 200)
}

pub fn view_show_service(_req: Request, unit: String) -> Response {
  let service = systemd.query_service(unit)
  let json_string = service |> systemd_json.service_to_json |> json.to_string
  let link = "/api/services/" <> unit

  let html =
    html([], [
      html.body([], [
        html.h1([], [html.text("systemd service: " <> unit)]),
        html.a([attribute.href(link)], [html.text("api")]),
        html.pre([], [html.text(json_string)]),
      ]),
    ])

  let html_string =
    html
    |> element.to_document_string

  wisp.html_response(html_string, 200)
}

pub fn api_show_service(req: Request, unit: String) -> Response {
  use <- wisp.require_method(req, http.Get)

  let service = systemd.query_service(unit)
  case service.load_state {
    systemd_status.NotFound ->
      http_json.error_json("systemd service not found: " <> unit)
      |> json.to_string
      |> wisp.json_response(404)
    _ ->
      service
      |> systemd_json.service_to_json
      |> json.to_string
      |> wisp.json_response(200)
  }
}
