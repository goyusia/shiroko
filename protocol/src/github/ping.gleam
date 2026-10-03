import github/common
import gleam/dynamic/decode
import gleam/json

pub type Payload {
  Payload(
    zen: String,
    hook_id: Int,
    hook: Hook,
    repository: common.Repository,
    sender: common.User,
  )
}

pub fn payload_from_json(
  json_string: String,
) -> Result(Payload, json.DecodeError) {
  json.parse(from: json_string, using: payload_decoder())
}

fn payload_decoder() -> decode.Decoder(Payload) {
  use zen <- decode.field("zen", decode.string)
  use hook_id <- decode.field("hook_id", decode.int)
  use hook <- decode.field("hook", hook_decoder())
  use repository <- decode.field("repository", common.repository_decoder())
  use sender <- decode.field("sender", common.user_decoder())
  decode.success(Payload(zen:, hook_id:, hook:, repository:, sender:))
}

pub type Hook {
  Hook(
    hook_type: String,
    id: Int,
    name: String,
    active: Bool,
    events: List(String),
    config: HookConfig,
  )
}

fn hook_decoder() -> decode.Decoder(Hook) {
  use hook_type <- decode.field("type", decode.string)
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use active <- decode.field("active", decode.bool)
  use events <- decode.field("events", decode.list(decode.string))
  use config <- decode.field("config", hook_config_decoder())
  decode.success(Hook(hook_type:, id:, name:, active:, events:, config:))
}

pub type HookConfig {
  HookConfig(
    content_type: String,
    insecure_ssl: String,
    secret: String,
    url: String,
  )
}

fn hook_config_decoder() -> decode.Decoder(HookConfig) {
  use content_type <- decode.field("content_type", decode.string)
  use insecure_ssl <- decode.field("insecure_ssl", decode.string)
  use secret <- decode.field("secret", decode.string)
  use url <- decode.field("url", decode.string)
  decode.success(HookConfig(content_type:, insecure_ssl:, secret:, url:))
}
