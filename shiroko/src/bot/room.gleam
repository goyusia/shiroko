import bot/contract
import bot/job
import feature
import feature/core.{type Reporter}
import feature/counter
import feature/ops
import github
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/string

type Memory {
  Memory(counter: counter.State, blank: Int)
}

type State {
  State(
    room_id: String,
    memory: Memory,
    job_registry_name: process.Name(job.Message),
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
          let args = ["shiroko", payload.after]
          ops.execute_deploy(args, reporter)
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

  let argv =
    line
    |> string.split(" ")
    |> list.filter(fn(s) { s != "" })

  let next = dispatch(state, argv, reporter)
  case next {
    Ok(next) -> actor.continue(next)
    Error(_) -> actor.continue(state)
  }
}

fn dispatch(state: State, argv: List(String), reporter: Reporter) {
  let job_registry = process.named_subject(state.job_registry_name)

  let fn_simple = feature.create_simple_handler(argv)
  let fn_counter = feature.create_counter_handler(argv, state.memory.counter)
  let fn_ps = feature.create_ps_handler(argv, job_registry)

  case fn_simple, fn_counter, fn_ps {
    Ok(f), _, _ -> {
      let fun = fn() { f(reporter) }
      let _id = job.submit(job_registry, fun, state.room_id, argv)
      Ok(state)
    }
    _, Ok(f), _ -> {
      let next = f(reporter)
      let state = State(..state, memory: Memory(..state.memory, counter: next))
      Ok(state)
    }
    _, _, Ok(f) -> {
      f(reporter)
      Ok(state)
    }
    _, _, _ -> {
      case argv {
        ["!" <> command, ..] -> {
          reporter.send("unknown command: " <> command)
          Ok(state)
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
