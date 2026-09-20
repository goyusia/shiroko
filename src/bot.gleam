import bot/core
import bot/init
import gleam/otp/supervision

pub type Config =
  core.Config

pub fn supervised(config: Config) {
  supervision.supervisor(fn() { init.start_supervisor(config) })
}
