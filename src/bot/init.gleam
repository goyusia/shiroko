import bot/client
import bot/dispatcher
import bot/protocol.{type Config}
import bot/session
import gleam/erlang/process
import gleam/list
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import irc/outgoing

pub fn start_supervisor(config: Config) {
  let link =
    protocol.Link(
      session: process.new_name("session"),
      client: process.new_name("client"),
      dispatcher: process.new_name("dispatcher"),
    )

  let sup =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(supervision.worker(fn() { client.start_client(link) }))
    |> supervisor.add(
      supervision.worker(fn() { session.start_session(config, link) }),
    )
    |> supervisor.add(
      supervision.supervisor(fn() { dispatcher.start_supervisor(link) }),
    )
    |> supervisor.start()

  // 초기 접속 채널
  let session_subject = process.named_subject(link.session)
  config.channels
  |> list.map(outgoing.join)
  |> list.map(protocol.IrcOutgoing)
  |> list.map(process.send(session_subject, _))

  sup
}
