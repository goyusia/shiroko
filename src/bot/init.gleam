import bot/client
import bot/core.{type Config}
import bot/session
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision

pub fn start_supervisor(config: Config) {
  let session_name = process.new_name("session")
  let client_name = process.new_name("client")
  let ctx = core.Context(session_name, client_name)

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(supervision.worker(fn() { client.start_supervisor(ctx) }))
  |> supervisor.add(supervision.worker(fn() { session.start(config, ctx) }))
  |> supervisor.start()
}
