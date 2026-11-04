import gleam/dynamic/decode
import gleam/http
import gleam/http/request.{type Request}
import gleam/json
import gleam/option.{type Option, None, Some}

pub type Priority {
  Max
  High
  Normal
  Low
  Min
}

// https://docs.ntfy.sh/publish/
pub type Builder {
  Builder(
    server: String,
    topic: String,
    message: Option(String),
    title: Option(String),
    priority: Option(Priority),
    click: Option(String),
    tags: Option(List(String)),
  )
}

pub fn new() -> Builder {
  Builder(
    server: "https://ntfy.sh",
    topic: "",
    message: None,
    title: None,
    priority: None,
    click: None,
    tags: None,
  )
}

pub fn server(builder: Builder, server: String) -> Builder {
  Builder(..builder, server: server)
}

pub fn topic(builder: Builder, topic: String) -> Builder {
  Builder(..builder, topic: topic)
}

pub fn message(builder: Builder, message: String) -> Builder {
  Builder(..builder, message: option.Some(message))
}

pub fn title(builder: Builder, title: String) -> Builder {
  Builder(..builder, title: option.Some(title))
}

pub fn priority(builder: Builder, priority: Priority) -> Builder {
  Builder(..builder, priority: option.Some(priority))
}

pub fn click(builder: Builder, click: String) -> Builder {
  Builder(..builder, click: option.Some(click))
}

pub fn tags(builder: Builder, tags: List(String)) -> Builder {
  Builder(..builder, tags: option.Some(tags))
}

fn priority_to_json(priority: Priority) -> json.Json {
  let v = case priority {
    Max -> 5
    High -> 4
    Normal -> 3
    Low -> 2
    Min -> 1
  }
  json.int(v)
}

fn builder_to_json_body(builder: Builder) -> json.Json {
  [#("topic", json.string(builder.topic))]
  |> optional("message", builder.message, json.string)
  |> optional("title", builder.title, json.string)
  |> optional("tags", builder.tags, json.array(_, of: json.string))
  |> optional("priority", builder.priority, priority_to_json)
  |> optional("click", builder.click, json.string)
  |> json.object
}

fn optional(
  params: List(#(String, json.Json)),
  name: String,
  value: Option(a),
  fun: fn(a) -> json.Json,
) -> List(#(String, json.Json)) {
  case value {
    None -> params
    Some(v) -> [#(name, fun(v)), ..params]
  }
}

pub fn create_request(builder: Builder) -> Request(String) {
  let json_body = builder_to_json_body(builder)
  let assert Ok(base_req) = request.to(builder.server)
  base_req
  |> request.set_method(http.Post)
  |> request.set_body(json.to_string(json_body))
}

pub type NtfyResponse {
  Success(id: String, time: Int, expires: Int, event: String, topic: String)
  Failure(code: Int, http: Int, error: String)
}

pub fn decode_success(
  json_string: String,
) -> Result(NtfyResponse, json.DecodeError) {
  echo json_string
  let decoder = {
    use id <- decode.field("id", decode.string)
    use time <- decode.field("time", decode.int)
    use expires <- decode.field("expires", decode.int)
    use event <- decode.field("event", decode.string)
    use topic <- decode.field("topic", decode.string)
    decode.success(Success(id:, time:, expires:, event:, topic:))
  }
  json.parse(from: json_string, using: decoder)
}

pub fn decode_failure(
  json_string: String,
) -> Result(NtfyResponse, json.DecodeError) {
  echo json_string
  let decoder = {
    use code <- decode.field("code", decode.int)
    use http <- decode.field("http", decode.int)
    use error <- decode.field("error", decode.string)
    decode.success(Failure(code:, http:, error:))
  }
  json.parse(from: json_string, using: decoder)
}
