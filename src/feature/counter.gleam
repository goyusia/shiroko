import feature/contract.{type Responder}
import gleam/int
import gleam/json

pub type State {
  State(counter: Int)
}

pub fn dispatch(
  state: State,
  tokens: List(String),
  respond: Responder,
) -> Result(State, Nil) {
  case tokens {
    ["!counter.show"] -> {
      state
      |> state_to_json
      |> json.to_string
      |> respond
      Ok(state)
    }
    ["!counter.inc"] -> {
      let next = state.counter + 1
      respond("counter: " <> int.to_string(next))
      Ok(State(counter: next))
    }
    ["!counter.reset"] -> {
      respond("counter: 0")
      Ok(State(counter: 0))
    }
    _ -> Error(Nil)
  }
}

fn state_to_json(state: State) -> json.Json {
  json.object([
    #("counter", json.int(state.counter)),
  ])
}
