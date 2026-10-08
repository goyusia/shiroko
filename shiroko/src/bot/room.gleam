import bot/contract
import bot/job_registry
import feature
import feature/core.{type Reporter}
import feature/counter
import feature/ops
import github
import gleam/erlang/process
import gleam/otp/actor
import gleam/string

type Memory {
  Memory(counter: counter.State, blank: Int)
}

type State {
  State(
    room_id: String,
    memory: Memory,
    job_registry_name: process.Name(job_registry.Message),
    adapter: contract.Adapter,
  )
}

pub type Message {
  RoomText(text: String)
  RoomGitHubWebhook(
    payload: github.WebhookPayload,
    headers: github.WebhookHeaders,
  )
}

pub type RoomStart {
  RoomStart(room_id: String, room_name: process.Name(Message))
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    RoomText(text) -> handle_text(state, text)
    RoomGitHubWebhook(payload, headers) ->
      handle_github_webhook(state, payload, headers)
  }
}

fn handle_text(state: State, text: String) -> actor.Next(State, Message) {
  case string.starts_with(text, "!") {
    True -> handle_command(state, text)
    False -> actor.continue(state)
  }
}

fn handle_github_webhook(
  state: State,
  payload: github.WebhookPayload,
  _headers: github.WebhookHeaders,
) -> actor.Next(State, Message) {
  case payload {
    github.Push(payload) -> {
      let channel = "#homelab-activity"
      let respond = state.adapter.send_text(channel, _)
      let reporter = core.Reporter(respond)

      let repository = payload.repository
      case repository.name, payload.ref {
        "shiroko", "refs/heads/deploy" -> {
          let argv = ["shiroko", payload.after]
          ops.execute_deploy(argv, reporter)
          Nil
        }
        _, _ -> Nil
      }

      Nil
    }
    _ -> Nil
  }
  actor.continue(state)
}

fn send_text(state: State, text: String) {
  state.adapter.send_text(state.room_id, text)
}

fn handle_command(state: State, line: String) -> actor.Next(State, Message) {
  let respond = send_text(state, _)
  let reporter = core.Reporter(respond)

  let tokens = string.split(line, " ")
  let next = dispatch(state, state.memory, tokens, reporter)
  case next {
    Ok(memory) -> actor.continue(State(..state, memory:))
    Error(_) -> actor.continue(state)
  }
}

fn dispatch(
  state: State,
  mem: Memory,
  tokens: List(String),
  reporter: Reporter,
) {
  let fn_simple = feature.create_simple_handler(tokens)
  let fn_counter = feature.create_counter_handler(tokens, mem.counter)
  case fn_simple, fn_counter {
    Ok(f), _ -> {
      let subject = process.named_subject(state.job_registry_name)
      actor.send(subject, job_registry.Spawn(fn() { f(reporter) }))
      Ok(mem)
    }
    _, Ok(f) -> {
      let next = f(reporter)
      let mem = Memory(..mem, counter: next)
      Ok(mem)
    }
    _, _ -> {
      case tokens {
        ["!" <> command, ..] -> {
          reporter.send("unknown command: " <> command)
          Ok(mem)
        }
        _ -> Error(Nil)
      }
    }
  }
}

pub fn start_worker(
  arg: RoomStart,
  job_registry_name,
  adapter: contract.Adapter,
) {
  let memory = Memory(counter: counter.State(counter: 0), blank: 0)
  let initial = State(arg.room_id, memory, job_registry_name, adapter)
  actor.new(initial)
  |> actor.named(arg.room_name)
  |> actor.on_message(handle_message)
  |> actor.start
}
