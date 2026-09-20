import bot/core.{type IrcEndpoint, type IrcIdentity}
import bot/irc_channel
import bot/login
import bot/plugin
import gleam/bit_array
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/string
import irc
import irc/message
import irc/outgoing
import irc/reader
import logging
import mug

type State {
  State(subject: process.Subject(Message), socket: mug.Socket, buffer: BitArray)
}

pub type Message {
  Tcp(mug.TcpMessage)
  IrcOutgoing(irc.Message)
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Tcp(mug.Packet(socket, packet)) -> {
      mug.receive_next_packet_as_message(socket)
      handle_packet(state, packet)
    }
    Tcp(mug.SocketClosed(_socket)) -> {
      let reason = "socket closed"
      logging.log(logging.Warning, reason)
      actor.stop_abnormal(reason)
    }
    Tcp(mug.TcpError(_socket, error)) -> {
      let reason = string.inspect(error)
      logging.log(logging.Critical, reason)
      actor.stop_abnormal(reason)
    }
    IrcOutgoing(message) -> {
      handle_irc_outgoing(state, message)
    }
  }
}

fn handle_packet(state: State, packet: BitArray) -> actor.Next(State, Message) {
  let buffer = bit_array.append(state.buffer, packet)
  let #(lines, buffer) = reader.extract_lines(buffer)
  let state = State(..state, buffer:)

  // TODO: 메세지 처리는 루프를 막으면 안된다
  list.each(lines, handle_line(_, state.socket))

  actor.continue(state)
}

fn handle_line(line: String, socket: mug.Socket) {
  use msg <- result.try(message.parse(line))
  let _ = case msg.command, msg.params {
    "PRIVMSG", [dest, ..] -> {
      let reply = core.send_line(socket, dest, _)
      plugin.dispatch(msg, reply)
    }
    "PING", _ -> {
      message.Message(..msg, command: "PONG")
      |> core.send_single(socket, _)
    }
    "INVITE", [_nickname, channel] -> {
      irc_channel.join(socket, channel)
    }
    _, _ -> {
      logging.log(logging.Info, "irc packet: " <> line)
      Ok(Nil)
    }
  }
  Ok(Nil)
}

fn handle_irc_outgoing(
  state: State,
  message: irc.Message,
) -> actor.Next(State, Message) {
  let _ = core.send_single(state.socket, message)
  actor.continue(state)
}

pub fn start(config: core.Config) {
  actor.new_with_initialiser(1000, fn(subject) {
    case connect(config.endpoint, config.identity) {
      Ok(socket) -> {
        let selector =
          process.new_selector()
          |> mug.select_tcp_messages(fn(msg) { Tcp(msg) })
          |> process.select(for: subject)
        mug.receive_next_packet_as_message(socket)

        // 초기 접속 채널
        config.channels
        |> list.map(outgoing.join)
        |> list.map(IrcOutgoing)
        |> list.map(process.send(subject, _))

        let state = State(subject, socket, <<>>)
        Ok(
          actor.initialised(state)
          |> actor.selecting(selector)
          |> actor.returning(subject),
        )
      }
      Error(error) -> {
        // TODO: socket 에러로 irc 연결 초기화 불가능할때는 어떻게 처리하는게 좋을까
        logging.log(logging.Critical, string.inspect(error))
        panic as "irc session initialization failed"
      }
    }
  })
  |> actor.on_message(handle_message)
  |> actor.start()
}

fn connect(
  endpoint: IrcEndpoint,
  identity: IrcIdentity,
) -> Result(mug.Socket, core.Error) {
  // TODO: 더 안정적힌 처리 방법?
  use socket <- result.try(
    mug.new(endpoint.host, endpoint.port)
    |> mug.timeout(milliseconds: 500)
    |> mug.connect()
    |> result.map_error(core.ConnectionError),
  )

  use _ <- result.try(login.flow_login(socket, identity))
  Ok(socket)
}
