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
  let session_name = process.new_name("session")
  let client_name = process.new_name("client")
  let dispatcher_name = process.new_name("dispatcher")

  let client_worker =
    supervision.worker(fn() {
      client.start_client(client_name, session_name, dispatcher_name)
    })

  let session_worker =
    supervision.worker(fn() {
      session.start_session(config, session_name, client_name)
    })

  let dispatcher_supervisor =
    dispatcher.supervised(dispatcher_name, client_name)

  let sup =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(client_worker)
    |> supervisor.add(session_worker)
    |> supervisor.add(dispatcher_supervisor)
    |> supervisor.start()

  // 초기 접속 채널
  let session_subject = process.named_subject(session_name)
  config.channels
  |> list.map(outgoing.join)
  |> list.map(protocol.SessionIrcOutgoing)
  |> list.map(process.send(session_subject, _))

  // 기본 채널로 서버 버전 정보 알려주기. 자동 배포떄문에 있으면 편할거같은데
  let version = status.get_commit_id()
  let line = "bot: " <> version
  config.channels
  |> list.map(outgoing.privmsg(_, line))
  |> list.map(protocol.SessionIrcOutgoing)
  |> list.map(process.send(session_subject, _))

  sup
}
