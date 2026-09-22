import bot/client
import bot/dispatcher
import bot/protocol.{type Config}
import bot/session
import gleam/erlang/process
import gleam/list
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import irc/outgoing
import uptime/status

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

  // 기본 채널로 서버 버전 정보 알려주기. 자동 배포떄문에 있으면 편할거같은데
  let version = status.get_commit_id()
  let line = "bot: " <> version
  config.channels
  |> list.map(outgoing.privmsg(_, line))
  |> list.map(protocol.IrcOutgoing)
  |> list.map(process.send(session_subject, _))

  sup
}
