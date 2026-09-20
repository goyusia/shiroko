import bot/core
import bot/irc_channel
import bot/irc_client
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision

pub type Config =
  core.Config

pub fn supervised(config: Config) {
  supervision.supervisor(fn() { start_supervisor(config) })
}

fn start_supervisor(config: Config) {
  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(supervision.worker(fn() { irc_client.start(config) }))
  |> supervisor.add(supervision.worker(fn() { irc_channel.start_supervisor() }))
  |> supervisor.start()
}
