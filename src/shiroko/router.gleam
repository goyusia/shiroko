import lustre/attribute
import lustre/element
import lustre/element/html.{html}
import shiroko/web
import shiroko/web/system
import uptime/router as uptime_router
import uptime/uptime
import wisp.{type Request, type Response}

pub fn handle_request(
  uptime_service: uptime.ProbeRegistry,
  req: Request,
) -> Response {
  use _req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> index(req)
    ["uptime", "systemd", unit] -> uptime_router.page_systemd(req, unit)
    ["uptime"] -> uptime_router.page_list(req, uptime_service)
    ["api", "uptime", "systemd", unit] -> uptime_router.api_systemd(req, unit)
    ["api", "uptime", "probe", service] ->
      uptime_router.api_probe(req, service, uptime_service)
    ["healthz"] -> system.healthz(req)
    ["readyz"] -> system.readyz(req)
    ["startupz"] -> system.startupz(req)
    ["version"] -> system.version(req)
    _ -> wisp.not_found()
  }
}

fn index(_req: Request) -> Response {
  let html =
    html([], [
      html.body([], [
        html.h1([], [html.text("shiroko")]),
        html.a([attribute.href("/uptime")], [html.text("uptime")]),
      ]),
    ])

  let body = html |> element.to_document_string
  wisp.html_response(body, 200)
}
