import lustre/attribute
import lustre/element
import lustre/element/html.{html}
import shiroko/web
import shiroko/web/service
import shiroko/web/system
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use _req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> index(req)
    ["services", unit] -> service.view_show_service(req, unit)
    ["services"] -> service.view_list_service(req)
    ["api", "services", unit] -> service.api_show_service(req, unit)
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
        html.a([attribute.href("/services")], [html.text("systemd services")]),
      ]),
    ])

  let body = html |> element.to_document_string
  wisp.html_response(body, 200)
}
