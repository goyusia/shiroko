import clip
import clip/arg
import clip/help
import feature/contract.{type Reporter}
import gleam/int
import gleam/json

pub type State {
  State(counter: Int)
}

type AddInput {
  AddInput(step: Int)
}

fn add_command() {
  let step_arg = arg.new("step") |> arg.int()
  clip.command({
    use step <- clip.parameter
    AddInput(step)
  })
  |> clip.arg(step_arg)
  |> clip.help(help.simple(
    "!counter.add",
    "Increment the counter by a given step",
  ))
}

pub fn execute_add(state: State, argv: List(String), reporter: Reporter) {
  echo argv
  case add_command() |> clip.run(argv) {
    Ok(input) -> {
      echo input
      let next = state.counter + input.step
      reporter.send("counter: " <> int.to_string(next))
      State(counter: next)
    }
    Error(e) -> {
      reporter.send(e)
      state
    }
  }
}

pub fn execute_reset(_state, _argv: List(String), reporter: Reporter) {
  reporter.send("counter: 0")
  State(counter: 0)
}

pub fn execute_show(state: State, argv: List(String), reporter: Reporter) {
  case contract.none_command() |> clip.run(argv) {
    Ok(_) -> handle_show(state, reporter)
    Error(e) -> {
      reporter.send(e)
      state
    }
  }
}

fn handle_show(state: State, reporter: Reporter) {
  state
  |> state_to_json
  |> json.to_string
  |> reporter.send
  state
}

fn state_to_json(state: State) -> json.Json {
  json.object([
    #("counter", json.int(state.counter)),
  ])
}
