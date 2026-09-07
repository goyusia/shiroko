import lustre/attribute
import lustre/element
import lustre/element/html.{html}
import shiroko/web
import shiroko/web/system
import uptime/router as uptime_router
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use _req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> index(req)
    ["uptime", unit] -> uptime_router.page_show(req, unit)
    ["uptime"] -> uptime_router.page_list(req)
    ["api", "uptime", unit] -> uptime_router.api_show(req, unit)
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
