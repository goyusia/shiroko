import github/common
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}

pub type Payload {
  Payload(
    ref: String,
    before: String,
    after: String,
    repository: common.Repository,
    pusher: Pusher,
    forced: Bool,
    sender: common.User,
    created: Bool,
    deleted: Bool,
    base_ref: Option(String),
    compare: String,
    commits: List(common.Commit),
    head_commit: common.Commit,
  )
}

pub fn payload_from_json(
  json_string: String,
) -> Result(Payload, json.DecodeError) {
  json.parse(from: json_string, using: payload_decoder())
}

fn payload_decoder() -> decode.Decoder(Payload) {
  use ref <- decode.field("ref", decode.string)
  use before <- decode.field("before", decode.string)
  use after <- decode.field("after", decode.string)
  use repository <- decode.field("repository", common.repository_decoder())
  use pusher <- decode.field("pusher", pusher_decoder())
  use forced <- decode.field("forced", decode.bool)
  use sender <- decode.field("sender", common.user_decoder())
  use created <- decode.field("created", decode.bool)
  use deleted <- decode.field("deleted", decode.bool)
  use base_ref <- decode.field("base_ref", decode.optional(decode.string))
  use compare <- decode.field("compare", decode.string)
  use commits <- decode.field("commits", decode.list(common.commit_decoder()))
  use head_commit <- decode.field("head_commit", common.commit_decoder())
  decode.success(Payload(
    ref:,
    before:,
    after:,
    repository:,
    pusher:,
    forced:,
    sender:,
    created:,
    deleted:,
    base_ref:,
    compare:,
    commits:,
    head_commit:,
  ))
}

pub type Pusher {
  Pusher(name: String, email: String)
}

fn pusher_decoder() -> decode.Decoder(Pusher) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(Pusher(name:, email:))
}
