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
  let text = "농업생산성의 제고와 농지의 합리적인 이용을 위하거나 불가피한 사정으로 발생하는 농지의 임대차와 위탁경영은 법률이 정하는 바에 의하여 인정된다.  헌법재판소의 장은 국회의 동의를 얻어 재판관중에서 대통령이 임명한다. 국가는 재해를 예방하고 그 위험으로부터 국민을 보호하기 위하여 노력하여야 한다.

  명령·규칙 또는 처분이 헌법이나 법률에 위반되는 여부가 재판의 전제가 된 경우에는 대법원은 이를 최종적으로 심사할 권한을 가진다. 모든 국민은 법률이 정하는 바에 의하여 선거권을 가진다.  지방의회의 조직·권한·의원선거와 지방자치단체의 장의 선임방법 기타 지방자치단체의 조직과 운영에 관한 사항은 법률로 정한다. 대통령은 법률이 정하는 바에 의하여 훈장 기타의 영전을 수여한다."
  //reporter.send("pong: " <> kst_now())
  reporter.send(text)
}

fn ping_lazy(input: PingInput, reporter: Reporter) {
  process.spawn_unlinked(fn() {
    process.sleep(input.delay_ms)
    reporter.send("pong: " <> kst_now())
  })
  Nil
}

fn panic_command() {
  clip.return(Nil)
  |> clip.help(help.simple("!panic", "panic"))
}

pub fn execute_panic(argv: List(String), reporter: Reporter) {
  case panic_command() |> clip.run(argv) {
    Ok(_) -> handle_panic(Nil, reporter)
    Error(e) -> reporter.send(e)
  }
}

fn handle_panic(_input, _reporter) {
  panic as "panic by irc command"
}
