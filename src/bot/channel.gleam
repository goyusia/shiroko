import bot/protocol.{type ChannelStart}
import feature/contract.{type Reply}
import feature/counter
import feature/ops
import feature/system
import gleam/erlang/process
import gleam/otp/actor
import gleam/result
import gleam/string
import irc/outgoing

type Memory {
  Memory(counter: counter.State)
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
  let reply = send_line(state, _)
  let tokens = string.split(line, " ")

  let next = dispatch(state.memory, tokens, reply)
  case next {
    Ok(memory) -> actor.continue(State(..state, memory:))
    Error(_) -> actor.continue(state)
  }
}

fn dispatch(mem: Memory, tokens: List(String), reply: Reply) {
  use _ <- result.try_recover(dispatch_system(mem, tokens, reply))
  use _ <- result.try_recover(dispatch_counter(mem, tokens, reply))
  use _ <- result.try_recover(dispatch_ops(mem, tokens, reply))

  case tokens {
    ["!" <> command, ..] -> {
      reply("unknown command: " <> command)
      Ok(mem)
    }
    _ -> Error(Nil)
  }
}

fn dispatch_system(mem: Memory, tokens: List(String), reply: Reply) {
  use _ <- result.try(system.dispatch(Nil, tokens, reply))
  Ok(mem)
}

fn dispatch_counter(mem: Memory, tokens: List(String), reply: Reply) {
  use next <- result.try(counter.dispatch(mem.counter, tokens, reply))
  Ok(Memory(counter: next))
}

fn dispatch_ops(mem: Memory, tokens: List(String), reply: Reply) {
  use _ <- result.try(ops.dispatch(Nil, tokens, reply))
  Ok(mem)
}

pub fn start_worker(arg: ChannelStart) {
  let memory = Memory(counter: counter.State(counter: 0))
  let initial = State(arg.channel, memory, arg.link)
  actor.new(initial)
  |> actor.named(arg.name)
  |> actor.on_message(handle_message)
  |> actor.start
}
