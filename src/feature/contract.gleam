import clip

pub type Responder =
  fn(String) -> Nil

pub type Reporter {
  Reporter(send: Responder)
}

pub fn check_trigger(
  argv: List(String),
  trigger: String,
) -> Result(List(String), Nil) {
  case argv {
    [first, ..rest] if first == trigger -> Ok(rest)
    _ -> Error(Nil)
  }
}

pub fn none_command() {
  clip.return(Nil)
}
