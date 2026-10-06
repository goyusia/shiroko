import clip
import clip/arg
import clip/help
import feature/core.{type Reporter}
import gleam/int
import gleam/result
import gleam/string
import shellout
import uptime/status

@external(erlang, "uptime_ffi", "uptime")
fn erlang_uptime() -> #(Int, #(Int, Int, Int))

pub fn execute_uptime(argv: List(String), reporter: Reporter) {
  case core.none_command() |> clip.run(argv) {
    Ok(_) -> handle_uptime(reporter)
    Error(e) -> reporter.send(e)
  }
}

fn handle_uptime(reporter: Reporter) {
  let #(days, #(hours, minutes, seconds)) = erlang_uptime()
  let h = hours |> int.to_string
  let m = minutes |> int.to_string |> string.pad_start(2, "0")
  let s = seconds |> int.to_string |> string.pad_start(2, "0")
  let d = days |> int.to_string
  reporter.send(
    "shiroko uptime: " <> h <> ":" <> m <> ":" <> s <> " up " <> d <> " days",
  )
}

pub fn execute_version(argv: List(String), reporter: Reporter) {
  case core.none_command() |> clip.run(argv) {
    Ok(_) -> handle_version(reporter)
    Error(e) -> reporter.send(e)
  }
}

fn handle_version(reporter: Reporter) {
  let revision = status.get_commit_id()
  ["# shiroko version", "- commit id: " <> revision]
  |> string.join("\n")
  |> reporter.send
}

fn service_arg() {
  arg.new("service")
  |> arg.default("shiroko")
}

fn revision_arg() {
  arg.new("revision")
  |> arg.default("main")
}

type DeployInput {
  DeployInput(service: String, revision: String)
}

fn deploy_command() {
  clip.command({
    use service <- clip.parameter
    use revision <- clip.parameter
    DeployInput(service:, revision:)
  })
  |> clip.arg(service_arg())
  |> clip.arg(revision_arg())
  |> clip.help(help.simple("!ops.deploy", "deploy"))
}

pub fn execute_deploy(argv: List(String), reporter: Reporter) {
  case deploy_command() |> clip.run(argv) {
    Ok(input) -> {
      let _ = handle_deploy(input, reporter)
      Nil
    }
    Error(e) -> reporter.send(e)
  }
}

fn handle_deploy(input: DeployInput, reporter: Reporter) {
  let revision = input.revision
  case input.service {
    "shiroko" -> deploy_shiroko(revision, reporter)
    _ -> {
      reporter.send("ops.deploy: unknown service")
      Error(#(1, "unknown service"))
    }
  }
}

type RestartInput {
  RestartInput(service: String)
}

fn restart_command() {
  clip.command({
    use service <- clip.parameter
    RestartInput(service:)
  })
  |> clip.arg(service_arg())
  |> clip.help(help.simple("!ops.restart", "restart"))
}

pub fn execute_restart(argv: List(String), reporter: Reporter) {
  case restart_command() |> clip.run(argv) {
    Ok(input) -> {
      let _ = handle_restart(input, reporter)
      Nil
    }
    Error(e) -> reporter.send(e)
  }
}

fn handle_restart(input: RestartInput, reporter: Reporter) {
  case input.service {
    "shiroko" -> restart_shiroko(reporter)
    _ -> {
      reporter.send("ops.restart: unknown service")
      Error(#(1, "unknown service"))
    }
  }
}

fn deploy_shiroko(revision: String, reporter: Reporter) {
  reporter.send("shiroko.deploy: build " <> revision)

  let dir = "/home/maint/apps/shiroko/"
  use _ <- result.try(
    shellout.command("./scripts/build_prod.sh", [revision], dir, [])
    |> result.map(fn(output) {
      reporter.send(output)
      0
    }),
  )

  reporter.send("shiroko.deploy: restart daemon")
  use _ <- result.try(
    shellout.command("./scripts/server_restart.sh", [], dir, []),
  )
  Ok(0)
}

fn restart_shiroko(reporter: Reporter) {
  systemd_user_restart("shiroko", reporter)
}

fn systemd_user_restart(service: String, reporter: Reporter) {
  reporter.send("systemd.user.restart: restart " <> service)
  use _ <- result.try(
    shellout.command(
      run: "systemctl",
      with: ["--user", "restart", service],
      in: ".",
      opt: [],
    ),
  )
  Ok(0)
}
