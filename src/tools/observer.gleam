import gleam/dynamic.{type Dynamic}

@external(erlang, "observer", "start")
fn observer_start() -> Dynamic

pub fn start() -> Nil {
  let _ = observer_start()
  Nil
}
