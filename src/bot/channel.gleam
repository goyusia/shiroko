import bot/plugin
import bot/protocol.{type ChannelStart}
import gleam/erlang/process
import gleam/json
import gleam/otp/actor
import gleam/string
import irc/outgoing

type Memory {
  Memory(last_text: String, counter: Int)
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

  let memory = state.memory
  let memory = case tokens {
    ["!memory"] -> {
      memory
      |> memory_to_json
      |> json.to_string
      |> reply
      memory
    }
    ["!counter.inc"] -> {
      Memory(..memory, counter: memory.counter + 1)
    }
    ["!counter.reset"] -> {
      Memory(..memory, counter: 0)
    }
    _ -> {
      plugin.dispatch(tokens, reply)
      memory
    }
  }

  let memory = Memory(..memory, last_text: line)
  let state = State(..state, memory: memory)
  actor.continue(state)
}

fn memory_to_json(memory: Memory) -> json.Json {
  json.object([
    #("counter", json.int(memory.counter)),
    #("last_text", json.string(memory.last_text)),
  ])
}

pub fn start_worker(arg: ChannelStart) {
  let memory = Memory(last_text: "", counter: 0)
  let initial = State(arg.channel, memory, arg.link)
  actor.new(initial)
  |> actor.named(arg.name)
  |> actor.on_message(handle_message)
  |> actor.start
}
