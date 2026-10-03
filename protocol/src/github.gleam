import github/ping
import github/push
import gleam/bit_array
import gleam/dict
import gleam/json
import gleam/result

pub type WebhookPayload {
  Ping(ping.Payload)
  Push(push.Payload)
}

pub type DecodeError {
  BodyDecodeError
  JsonDecodeError(json.DecodeError)
  UnknownEvent
}

pub fn payload_from_request_body(
  body: BitArray,
  github_event: String,
) -> Result(WebhookPayload, DecodeError) {
  use json_string <- result.try(
    body
    |> bit_array.to_string()
    |> result.map_error(fn(_) { BodyDecodeError }),
  )
  case github_event {
    "ping" ->
      ping.payload_from_json(json_string)
      |> result.map(Ping)
      |> result.map_error(JsonDecodeError)
    "push" ->
      push.payload_from_json(json_string)
      |> result.map(Push)
      |> result.map_error(JsonDecodeError)
    _ -> Error(UnknownEvent)
  }
}

pub type WebhookHeaders {
  WebhookHeaders(
    content_type: String,
    user_agent: String,
    github_delivery: String,
    github_event: String,
    hook_id: String,
    hook_installation_target_id: String,
    hook_installation_target_type: String,
    hub_signature: String,
    hub_signature_256: String,
  )
}

pub fn headers_from_request_headers(headers: List(#(String, String))) {
  let table = dict.from_list(headers)
  let unwrap = fn(key: String) { table |> dict.get(key) |> result.unwrap("") }

  WebhookHeaders(
    content_type: unwrap("content-type"),
    user_agent: unwrap("user-agent"),
    github_delivery: unwrap("x-github-delivery"),
    github_event: unwrap("x-github-event"),
    hook_id: unwrap("x-github-hook-id"),
    hook_installation_target_id: unwrap("x-github-hook-installation-target-id"),
    hook_installation_target_type: unwrap(
      "x-github-hook-installation-target-type",
    ),
    hub_signature: unwrap("x-hub-signature"),
    hub_signature_256: unwrap("x-hub-signature-256"),
  )
}
