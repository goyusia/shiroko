import gleam/json

pub fn error_json(error: String) -> json.Json {
  json.object([
    #("error", json.string(error)),
  ])
}
