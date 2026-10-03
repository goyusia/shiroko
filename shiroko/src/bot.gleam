import adapter/adapter
import adapter/protocol
import adapter/session
import bot/contract
import bot/dispatcher
import gleam/erlang/process
import gleam/list
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import irc/outgoing
import uptime/status

pub type Config {
  Config(
    endpoint: protocol.Endpoint,
    identity: protocol.Identity,
    channels: List(String),
    dispatcher_name: process.Name(dispatcher.Message),
  )
}

pub fn supervised(config: Config) {
  supervision.supervisor(fn() { start_supervisor(config) })
}

fn start_supervisor(config: Config) {
  let session_name = process.new_name("session")
  let adapter_name = process.new_name("adapter")
  let dispatcher_name = config.dispatcher_name

  let adapter_worker =
    supervision.worker(fn() {
      adapter.start_adapter(adapter_name, session_name, dispatcher_name)
    })

  let session_supervisor =
    session.supervised(
      config.endpoint,
      config.identity,
      session_name,
      adapter_name,
    )

  let send_text = fn(room_id: String, text: String) {
    let subject = process.named_subject(adapter_name)
    process.send(subject, protocol.OutgoingText(room_id, text))
  }
  let adapter = contract.Adapter(send_text)
  let dispatcher_supervisor = dispatcher.supervised(dispatcher_name, adapter)

  let sup =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(adapter_worker)
    |> supervisor.add(session_supervisor)
    |> supervisor.add(dispatcher_supervisor)
    |> supervisor.start()

  // 초기 접속 채널
  let session_subject = process.named_subject(session_name)
  config.channels
  |> list.map(outgoing.join)
  |> list.map(protocol.OutgoingIrc)
  |> list.map(process.send(session_subject, _))

  // 기본 채널로 서버 버전 정보 알려주기. 자동 배포떄문에 있으면 편할거같은데
  let version = status.get_commit_id()
  let line = "bot: " <> version
  config.channels
  |> list.map(outgoing.privmsg(_, line))
  |> list.map(protocol.OutgoingIrc)
  |> list.map(process.send(session_subject, _))

  sup
}
