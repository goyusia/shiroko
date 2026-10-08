import feature/probing
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{html}
import shiroko/web.{type Context}
import shiroko/web/webhook
import shiroko/web/zpage
import stdx/viewx
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use _req <- web.middleware(req, ctx)

  let web.Context(
    probe_registry: probe_registry,
    static_directory: _static_directory,
    dispatcher_name: _dispatcher_name,
  ) = ctx

  case wisp.path_segments(req) {
    [] -> page_index(req)
    ["probe", ..] | ["api", "probe", ..] ->
      probing.handle_request(req, probe_registry)
    ["webhook", "github"] -> webhook.github(req, ctx)
    ["healthz"] -> zpage.healthz(req)
    ["readyz"] -> zpage.readyz(req)
    ["startupz"] -> zpage.startupz(req)
    ["version"] -> zpage.version(req)
    _ -> wisp.not_found()
  }
}

fn view_index() -> Element(message) {
  html([], [
    viewx.head("shiroko"),
    html.body([], [
      html.h1([], [html.text("shiroko")]),
      html.a([attribute.href("/probe")], [html.text("probe")]),
    ]),
  ])
}

fn page_index(_req: Request) -> Response {
  view_index()
  |> element.to_document_string
  |> wisp.html_response(200)
}
