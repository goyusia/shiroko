import bot/init
import bot/protocol
import gleam/otp/supervision

pub type Config =
  protocol.Config

pub fn supervised(config: Config) {
  supervision.supervisor(fn() { init.start_supervisor(config) })
}
