import clip
import clip/help
import feature/core.{type Reporter}

fn crash_command() {
  clip.return(Nil)
  |> clip.help(help.simple("!crash", "crash"))
}

pub fn execute_crash(args: List(String), reporter: Reporter) {
  case crash_command() |> clip.run(args) {
    Ok(_) -> handle_crash(Nil, reporter)
    Error(e) -> reporter.send(e)
  }
}

fn handle_crash(_input, _reporter) {
  panic as "panic by irc command"
}
