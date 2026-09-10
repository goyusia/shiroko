import foundation/http_json
import gleam/http
import gleam/json
import gleam/list
import lustre/attribute
import lustre/element
import lustre/element/html.{html}
import systemd_status
import uptime/systemd
import uptime/uptime
import wisp.{type Request, type Response}

pub fn page_list(_req: Request, registry: uptime.ProbeRegistry) -> Response {
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
      let link = "/uptime/systemd/" <> unit
      html.li([], [html.a([attribute.href(link)], [html.text(unit)])])
    })

  let probes =
    uptime.states(registry)
    |> list.map(fn(result) {
      case result {
        #(name, Ok(state)) -> {
          let active = case state.histories {
            [uptime.Responded(..), ..] -> "active"
            _ -> "inactive"
          }
          let link = "/api/uptime/probe/" <> name
          html.li([], [
            html.a([attribute.href(link)], [html.text(name)]),
            html.text(": " <> active),
          ])
        }
        #(name, Error(_)) -> html.li([], [html.text(name <> ": unavailable")])
      }
    })

  let html =
    html([], [
      html.body([], [
        html.h1([], [html.text("uptime")]),
        html.h2([], [html.text("probes")]),
        html.ul([], probes),
        html.h2([], [html.text("systemd")]),
        html.ul([], elements),
      ]),
    ])
    |> element.to_document_string
  wisp.html_response(html, 200)
}

pub fn page_systemd(_req: Request, unit: String) -> Response {
  let service = systemd.query_service(unit)
  let json_string = service |> systemd.service_to_json |> json.to_string
  let link = "/api/uptime/systemd/" <> unit

  let html =
    html([], [
      html.body([], [
        html.h1([], [html.text("uptime: " <> unit)]),
        html.a([attribute.href(link)], [html.text("api")]),
        html.pre([], [html.text(json_string)]),
      ]),
    ])

  let html_string =
    html
    |> element.to_document_string

  wisp.html_response(html_string, 200)
}

pub fn api_systemd(req: Request, unit: String) -> Response {
  use <- wisp.require_method(req, http.Get)

  let service = systemd.query_service(unit)
  case service.load_state {
    systemd_status.NotFound ->
      http_json.error_json("systemd service not found: " <> unit)
      |> json.to_string
      |> wisp.json_response(404)
    _ ->
      service
      |> systemd.service_to_json
      |> json.to_string
      |> wisp.json_response(200)
  }
}

pub fn api_probe(
  req: Request,
  name: String,
  registry: uptime.ProbeRegistry,
) -> Response {
  use <- wisp.require_method(req, http.Get)

  case uptime.state(registry, name) {
    Error(_) ->
      http_json.error_json("uptime probe not found: " <> name)
      |> json.to_string
      |> wisp.json_response(404)
    Ok(state) ->
      state
      |> uptime.state_to_json
      |> json.to_string
      |> wisp.json_response(200)
  }
}
