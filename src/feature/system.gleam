import clip
import clip/arg
import clip/help
import feature/contract.{type Reporter}
import gleam/erlang/process
import gleam/time/duration
import gleam/time/timestamp

pub fn execute_ping(argv: List(String), reporter: Reporter) {
  case contract.none_command() |> clip.run(argv) {
    Ok(_) -> handle_ping(Nil, reporter)
    Error(e) -> contract.send_error(e, reporter)
  }
}

fn handle_ping(_input, reporter: Reporter) {
  reporter.send("pong")
}

pub fn execute_panic(argv: List(String), reporter: Reporter) {
  case contract.none_command() |> clip.run(argv) {
    Ok(_) -> handle_panic(Nil, reporter)
    Error(e) -> contract.send_error(e, reporter)
  }
}

fn handle_panic(_input, _reporter) {
  panic as "panic by irc command"
}

type DelayInput {
  DelayInput(delay_ms: Int)
}

fn delay_command() {
  let millis_arg =
    arg.new("millis")
    |> arg.int()

  clip.command({
    use millis <- clip.parameter
    DelayInput(millis)
  })
  |> clip.arg(millis_arg)
  |> clip.help(help.simple("!delay", "delay"))
}

pub fn execute_delay(argv: List(String), reporter: Reporter) {
  case delay_command() |> clip.run(argv) {
    Ok(input) -> handle_delay(input, reporter)
    Error(e) -> contract.send_error(e, reporter)
  }
}

fn kst_now() {
  timestamp.system_time()
  |> timestamp.to_rfc3339(duration.hours(9))
}

fn handle_delay(input: DelayInput, reporter: Reporter) {
  reporter.send("delay: start " <> kst_now())

  process.spawn_unlinked(fn() {
    process.sleep(input.delay_ms)
    reporter.send("delay: end " <> kst_now())
  })
  Nil
}
