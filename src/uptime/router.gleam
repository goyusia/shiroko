import foundation/http_json
import foundation/page
import gleam/http
import gleam/json
import gleam/list
import lustre/attribute
import lustre/element
import lustre/element/html.{html}
import uptime/uptime
import wisp.{type Request, type Response}

pub fn page_list(_req: Request, registry: uptime.EndpointRegistry) -> Response {
  let endpoints =
    uptime.states(registry)
    |> list.map(fn(result) {
      case result {
        #(name, Ok(state)) -> {
          let active = case state.histories {
            [uptime.Responded(..), ..] -> "active"
            _ -> "inactive"
          }
          let link = "/api/uptime/" <> name
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
      page.view_head("uptime"),
      html.body([], [
        html.h1([], [html.text("uptime")]),
        html.h2([], [html.text("endpoints")]),
        html.ul([], endpoints),
      ]),
    ])
    |> element.to_document_string
  wisp.html_response(html, 200)
}

pub fn api_show(
  req: Request,
  name: String,
  registry: uptime.EndpointRegistry,
) -> Response {
  use <- wisp.require_method(req, http.Get)

  case uptime.state(registry, name) {
    Error(_) ->
      http_json.error_json("endpoint not found: " <> name)
      |> json.to_string
      |> wisp.json_response(404)
    Ok(state) ->
      state
      |> uptime.state_to_json
      |> json.to_string
      |> wisp.json_response(200)
  }
}
