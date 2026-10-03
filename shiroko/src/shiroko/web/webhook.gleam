import bot/dispatcher
import github
import gleam/bit_array
import gleam/erlang/process
import gleam/http
import gleam/string
import logging
import shiroko/web
import wisp.{type Request, type Response}

pub fn github(req: Request, ctx: web.Context) -> Response {
  use <- wisp.require_method(req, http.Post)
  use body <- wisp.require_bit_array_body(req)

  let headers = github.headers_from_request_headers(req.headers)
  let payload = github.payload_from_request_body(body, headers.github_event)
  case payload {
    Ok(inner) -> {
      case inner {
        github.Ping(payload) -> handle_ping(payload)
        github.Push(payload) -> handle_push(payload)
      }

      let room_id = "#internal"
      let message = dispatcher.DispatcherGitHubWebhook(room_id, inner, headers)
      let dispatcher_subject = process.named_subject(ctx.dispatcher_name)
      process.send(dispatcher_subject, message)
    }
    Error(github.UnknownEvent) -> {
      logging.log(logging.Error, "unknown event type: " <> headers.github_event)
    }
    Error(_) -> {
      logging.log(logging.Error, "webhook headers: " <> string.inspect(headers))
      logging.log(logging.Error, "webhook payload: " <> dump_body(body))
    }
  }

  wisp.ok()
}

fn handle_ping(payload: github.PingPayload) {
  let text = "ping: repository=" <> payload.repository.full_name
  logging.log(logging.Info, text)
  Nil
}

fn handle_push(payload: github.PushPayload) {
  let text =
    "push: repository="
    <> payload.repository.full_name
    <> " commit="
    <> payload.after
  logging.log(logging.Info, text)
  Nil
}

fn dump_body(body: BitArray) -> String {
  case bit_array.to_string(body) {
    Ok(body) -> body
    Error(_) -> bit_array.inspect(body)
  }
}
