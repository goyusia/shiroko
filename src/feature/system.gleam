import clip
import clip/arg
import clip/help
import feature/contract.{type Reporter}
import gleam/erlang/process
import gleam/time/duration
import gleam/time/timestamp

type PingInput {
  PingInput(delay_ms: Int)
}

fn ping_command() {
  let millis_arg =
    arg.new("millis")
    |> arg.int()
    |> arg.default(0)

  clip.command({
    use millis <- clip.parameter
    PingInput(millis)
  })
  |> clip.arg(millis_arg)
  |> clip.help(help.simple("!ping", "ping"))
}

pub fn execute_ping(argv: List(String), reporter: Reporter) {
  case ping_command() |> clip.run(argv) {
    Ok(input) -> handle_ping(input, reporter)
    Error(e) -> reporter.send(e)
  }
}

fn handle_ping(input: PingInput, reporter: Reporter) {
  case input.delay_ms {
    0 -> ping_immediate(input, reporter)
    _ -> ping_lazy(input, reporter)
  }
}

fn kst_now() {
  timestamp.system_time()
  |> timestamp.to_rfc3339(duration.hours(9))
}

fn ping_immediate(_input, reporter: Reporter) {
  reporter.send("pong: " <> kst_now())
}

fn ping_lazy(input: PingInput, reporter: Reporter) {
  process.spawn_unlinked(fn() {
    process.sleep(input.delay_ms)
    reporter.send("pong: " <> kst_now())
  })
  Nil
}

pub fn execute_panic(argv: List(String), reporter: Reporter) {
  case contract.none_command() |> clip.run(argv) {
    Ok(_) -> handle_panic(Nil, reporter)
    Error(e) -> reporter.send(e)
  }
}

fn handle_panic(_input, _reporter) {
  panic as "panic by irc command"
}
