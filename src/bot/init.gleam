import bot/client
import bot/protocol.{type Config}
import bot/router
import bot/session
import gleam/erlang/process
import gleam/list
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import irc/outgoing

pub fn start_supervisor(config: Config) {
  let session_name = process.new_name("session")
  let client_name = process.new_name("client")
  let router_name = process.new_name("router")
  let link =
    protocol.Link(
      session: session_name,
      client: client_name,
      router: router_name,
    )

  let sup =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(supervision.worker(fn() { client.start_client(link) }))
    |> supervisor.add(
      supervision.worker(fn() { session.start_session(config, link) }),
    )
    |> supervisor.add(
      supervision.supervisor(fn() { router.start_supervisor(link) }),
    )
    |> supervisor.start()

  // 초기 접속 채널
  let session_subject = process.named_subject(session_name)
  config.channels
  |> list.map(outgoing.join)
  |> list.map(protocol.IrcOutgoing)
  |> list.map(process.send(session_subject, _))

  sup
}
