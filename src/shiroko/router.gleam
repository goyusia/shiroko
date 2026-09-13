import foundation/page
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{html}
import shiroko/web.{type Context}
import shiroko/web/ops
import shiroko/web/webhook
import shiroko/web/zpage
import uptime/router as uptime_router
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use _req <- web.middleware(req, ctx)

  let web.Context(
    uptime_registry: uptime_registry,
    static_directory: _static_directory,
  ) = ctx

  case wisp.path_segments(req) {
    [] -> page_index(req)
    ["uptime"] -> uptime_router.page_list(req, uptime_registry)
    ["api", "uptime", service] ->
      uptime_router.api_show(req, service, uptime_registry)
    ["ops", "redeploy"] -> ops.redeploy(req)
    ["webhook", "github"] -> webhook.github(req)
    ["healthz"] -> zpage.healthz(req)
    ["readyz"] -> zpage.readyz(req)
    ["startupz"] -> zpage.startupz(req)
    ["version"] -> zpage.version(req)
    _ -> wisp.not_found()
  }
}

fn view_index() -> Element(message) {
  html([], [
    page.view_head("shiroko"),
    html.body([], [
      html.h1([], [html.text("shiroko")]),
      html.a([attribute.href("/uptime")], [html.text("uptime")]),
    ]),
  ])
}

fn page_index(_req: Request) -> Response {
  view_index()
  |> element.to_document_string
  |> wisp.html_response(200)
}
