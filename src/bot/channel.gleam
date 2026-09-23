import bot/protocol.{type ChannelStart}
import feature/contract.{type Reporter}
import feature/counter
import feature/ops
import feature/system
import gleam/erlang/process
import gleam/otp/actor
import gleam/string
import irc/outgoing

type Memory {
  Memory(counter: counter.State, blank: Int)
}

type State {
  State(channel_name: String, memory: Memory, link: protocol.Link)
}

type Message =
  protocol.ChannelMessage

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  let protocol.ChannelText(text:) = message
  case string.starts_with(text, "!") {
    True -> handle_command(state, text)
    False -> actor.continue(state)
  }
}

fn send_line(state: State, line: String) {
  outgoing.privmsg(state.channel_name, line)
  |> protocol.IrcOutgoing()
  |> process.send(protocol.session_subject(state.link), _)
}

fn handle_command(state: State, line: String) -> actor.Next(State, Message) {
  let respond = send_line(state, _)
  let reporter = contract.Reporter(respond)

  let tokens = string.split(line, " ")
  let next = dispatch(state.memory, tokens, reporter)
  case next {
    Ok(memory) -> actor.continue(State(..state, memory:))
    Error(_) -> actor.continue(state)
  }
}

fn dispatch(mem: Memory, tokens: List(String), reporter: Reporter) {
  case tokens {
    ["!ping", ..argv] -> {
      system.execute_ping(argv, reporter)
      Ok(mem)
    }
    ["!panic", ..argv] -> {
      system.execute_panic(argv, reporter)
      Ok(mem)
    }
    ["!delay", ..argv] -> {
      system.execute_delay(argv, reporter)
      Ok(mem)
    }
    ["!uptime", ..argv] -> {
      ops.execute_uptime(argv, reporter)
      Ok(mem)
    }
    ["!version", ..argv] -> {
      ops.execute_version(argv, reporter)
      Ok(mem)
    }
    ["!ops.redeploy", ..argv] -> {
      ops.execute_redeploy(argv, reporter)
      Ok(mem)
    }
    ["!counter.show", ..argv] -> {
      counter.execute_show(mem.counter, argv, reporter)
      |> apply_memory_counter(mem, _)
      |> Ok()
    }
    ["!counter.add", ..argv] -> {
      counter.execute_add(mem.counter, argv, reporter)
      |> apply_memory_counter(mem, _)
      |> Ok()
    }
    ["!counter.reset", ..argv] -> {
      counter.execute_reset(mem.counter, argv, reporter)
      |> apply_memory_counter(mem, _)
      |> Ok()
    }
    ["!" <> command, ..] -> {
      reporter.send("unknown command: " <> command)
      Ok(mem)
    }
    _ -> Error(Nil)
  }
}

fn apply_memory_counter(mem: Memory, counter: counter.State) -> Memory {
  Memory(counter: counter, blank: mem.blank)
}

pub fn start_worker(arg: ChannelStart) {
  let memory = Memory(counter: counter.State(counter: 0), blank: 0)
  let initial = State(arg.channel, memory, arg.link)
  actor.new(initial)
  |> actor.named(arg.name)
  |> actor.on_message(handle_message)
  |> actor.start
}
