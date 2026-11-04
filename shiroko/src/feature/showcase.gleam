import clip
import clip/help
import clip/opt
import feature/core
import gleam/http/response
import gleam/httpc
import gleam/string
import ntfy

fn title_opt() {
  opt.new("title")
  |> opt.default("sample title")
}

fn message_opt() {
  opt.new("message")
  |> opt.default("sample message")
}

type NtfyInput {
  NtfyInput(title: String, message: String)
}

fn ntfy_command() {
  clip.command({
    use title <- clip.parameter
    use message <- clip.parameter
    NtfyInput(title:, message:)
  })
  |> clip.opt(title_opt())
  |> clip.opt(message_opt())
  |> clip.help(help.simple("!showcase.ntfy", "ntfy"))
}

pub fn execute_ntfy(args: List(String), reporter: core.Reporter) {
  case ntfy_command() |> clip.run(args) {
    Ok(input) -> handle_ntfy(input, reporter)
    Error(e) -> reporter.send(e)
  }
}

fn handle_ntfy(input: NtfyInput, reporter: core.Reporter) {
  let req =
    ntfy.new()
    |> ntfy.server("http://ntfy.home.arpa")
    |> ntfy.topic("sandbox")
    |> ntfy.title(input.title)
    |> ntfy.message(input.message)
    |> ntfy.priority(ntfy.Normal)
    |> ntfy.click("http://hub.home.arpa")
    |> ntfy.create_request()

  let resp = httpc.send(req)
  case resp {
    Ok(resp) -> handle_ntfy_response(resp, reporter)
    Error(e) -> reporter.send("ntfy.error: " <> string.inspect(e))
  }
}

fn handle_ntfy_response(
  resp: response.Response(String),
  reporter: core.Reporter,
) {
  let decoded = case resp.status {
    200 -> ntfy.decode_success(resp.body)
    _ -> ntfy.decode_failure(resp.body)
  }

  case decoded {
    Ok(ntfy.Success(id, _, _, _, _)) -> reporter.send("ntfy: id=" <> id)
    Ok(ntfy.Failure(_, _, error)) -> reporter.send("ntfy.fail: error=" <> error)
    Error(e) -> reporter.send("ntfy.error: " <> string.inspect(e))
  }
}
