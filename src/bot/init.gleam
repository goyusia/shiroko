import bot/client
import bot/core.{type Config}
import bot/session
import gleam/erlang/process
import gleam/list
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import irc/outgoing

pub fn start_supervisor(config: Config) {
  let session_name = process.new_name("session")
  let client_name = process.new_name("client")
  let ctx = core.Context(session_name, client_name)

  let sup =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(supervision.worker(fn() { client.start_supervisor(ctx) }))
    |> supervisor.add(supervision.worker(fn() { session.start(config, ctx) }))
    |> supervisor.start()

  // 초기 접속 채널
  let session_subject = process.named_subject(session_name)
  config.channels
  |> list.map(outgoing.join)
  |> list.map(core.IrcOutgoing)
  |> list.map(process.send(session_subject, _))

  sup
}
