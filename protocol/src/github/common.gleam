import gleam/dynamic/decode
import gleam/json

pub type Repository {
  Repository(
    id: Int,
    node_id: String,
    name: String,
    full_name: String,
    private: Bool,
    owner: User,
    html_url: String,
    description: String,
    fork: Bool,
    url: String,
    language: String,
    topics: List(String),
    archived: Bool,
    disabled: Bool,
    visibility: String,
    default_branch: String,
  )
}

pub fn repository_decoder() -> decode.Decoder(Repository) {
  use id <- decode.field("id", decode.int)
  use node_id <- decode.field("node_id", decode.string)
  use name <- decode.field("name", decode.string)
  use full_name <- decode.field("full_name", decode.string)
  use private <- decode.field("private", decode.bool)
  use owner <- decode.field("owner", user_decoder())
  use html_url <- decode.field("html_url", decode.string)
  use description <- decode.field("description", decode.string)
  use fork <- decode.field("fork", decode.bool)
  use url <- decode.field("url", decode.string)
  use language <- decode.field("language", decode.string)
  use topics <- decode.field("topics", decode.list(decode.string))
  use archived <- decode.field("archived", decode.bool)
  use disabled <- decode.field("disabled", decode.bool)
  use visibility <- decode.field("visibility", decode.string)
  use default_branch <- decode.field("default_branch", decode.string)
  decode.success(Repository(
    id:,
    node_id:,
    name:,
    full_name:,
    private:,
    owner:,
    html_url:,
    description:,
    fork:,
    url:,
    language:,
    topics:,
    archived:,
    disabled:,
    visibility:,
    default_branch:,
  ))
}

pub fn repository_from_json(
  json_string: String,
) -> Result(Repository, json.DecodeError) {
  json.parse(from: json_string, using: repository_decoder())
}

pub type User {
  User(
    login: String,
    id: Int,
    node_id: String,
    avatar_url: String,
    gravatar_id: String,
    url: String,
    html_url: String,
    user_type: String,
    user_view_type: String,
    site_admin: Bool,
  )
}

pub fn user_decoder() -> decode.Decoder(User) {
  use login <- decode.field("login", decode.string)
  use id <- decode.field("id", decode.int)
  use node_id <- decode.field("node_id", decode.string)
  use avatar_url <- decode.field("avatar_url", decode.string)
  use gravatar_id <- decode.field("gravatar_id", decode.string)
  use url <- decode.field("url", decode.string)
  use html_url <- decode.field("html_url", decode.string)
  use user_type <- decode.field("type", decode.string)
  use user_view_type <- decode.field("user_view_type", decode.string)
  use site_admin <- decode.field("site_admin", decode.bool)
  decode.success(User(
    login:,
    id:,
    node_id:,
    avatar_url:,
    gravatar_id:,
    url:,
    html_url:,
    user_type:,
    user_view_type:,
    site_admin:,
  ))
}

pub fn user_from_json(json_string: String) -> Result(User, json.DecodeError) {
  json.parse(from: json_string, using: user_decoder())
}

pub type CommitSignature {
  CommitSignature(name: String, email: String, date: String)
}

pub fn commit_signature_decoder() -> decode.Decoder(CommitSignature) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  use date <- decode.field("date", decode.string)
  decode.success(CommitSignature(name:, email:, date:))
}

pub fn commit_signature_from_json(
  json_string: String,
) -> Result(CommitSignature, json.DecodeError) {
  json.parse(from: json_string, using: commit_signature_decoder())
}

pub type Commit {
  Commit(
    id: String,
    tree_id: String,
    distinct: Bool,
    message: String,
    timestamp: String,
    url: String,
    author: CommitSignature,
    committer: CommitSignature,
    added: List(String),
    removed: List(String),
    modified: List(String),
  )
}

pub fn commit_decoder() -> decode.Decoder(Commit) {
  use id <- decode.field("id", decode.string)
  use tree_id <- decode.field("tree_id", decode.string)
  use distinct <- decode.field("distinct", decode.bool)
  use message <- decode.field("message", decode.string)
  use timestamp <- decode.field("timestamp", decode.string)
  use url <- decode.field("url", decode.string)
  use author <- decode.field("author", commit_signature_decoder())
  use committer <- decode.field("committer", commit_signature_decoder())
  use added <- decode.field("added", decode.list(decode.string))
  use removed <- decode.field("removed", decode.list(decode.string))
  use modified <- decode.field("modified", decode.list(decode.string))
  decode.success(Commit(
    id:,
    tree_id:,
    distinct:,
    message:,
    timestamp:,
    url:,
    author:,
    committer:,
    added:,
    removed:,
    modified:,
  ))
}

pub fn commit_from_json(
  json_string: String,
) -> Result(Commit, json.DecodeError) {
  json.parse(from: json_string, using: commit_decoder())
}
