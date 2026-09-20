import bot/core.{type Endpoint, type Identity}
import bot/login
import gleam/bit_array
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/string
import irc
import irc/message
import irc/reader
import irc/verb
import logging
import mug

type Message =
  core.SessionMessage

type State {
  State(
    ctx: core.Context,
    subject: process.Subject(Message),
    socket: mug.Socket,
    buffer: BitArray,
  )
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    core.Tcp(mug.Packet(socket, packet)) -> {
      mug.receive_next_packet_as_message(socket)
      handle_packet(state, packet)
    }
    core.Tcp(mug.SocketClosed(_socket)) -> {
      let reason = "socket closed"
      logging.log(logging.Warning, reason)
      actor.stop_abnormal(reason)
    }
    core.Tcp(mug.TcpError(_socket, error)) -> {
      let reason = string.inspect(error)
      logging.log(logging.Critical, reason)
      actor.stop_abnormal(reason)
    }
    core.IrcOutgoing(message) -> {
      handle_irc_outgoing(state, message)
    }
  }
}

fn handle_packet(state: State, packet: BitArray) -> actor.Next(State, Message) {
  let buffer = bit_array.append(state.buffer, packet)
  let #(lines, buffer) = reader.extract_lines(buffer)
  let state = State(..state, buffer:)

  list.each(lines, handle_line(state, _))
  actor.continue(state)
}

fn handle_line(state: State, line: String) {
  use msg <- result.try(
    message.parse(line)
    |> result.map_error(fn(e) { core.BotError(string.inspect(e)) }),
  )

  case msg.command {
    "PING" -> {
      message.Message(..msg, command: verb.pong)
      |> core.send_single(state.socket, _)
    }
    _ -> {
      let subject = core.client_subject(state.ctx)
      process.send(subject, core.ClientMessage(msg, line))
      Ok(Nil)
    }
  }
}

fn handle_irc_outgoing(
  state: State,
  message: irc.Message,
) -> actor.Next(State, Message) {
  let _ = core.send_single(state.socket, message)
  actor.continue(state)
}

pub fn start(config: core.Config, ctx: core.Context) {
  actor.new_with_initialiser(1000, fn(subject) {
    case connect(config.endpoint, config.identity) {
      Ok(socket) -> {
        let selector =
          process.new_selector()
          |> mug.select_tcp_messages(fn(msg) { core.Tcp(msg) })
          |> process.select(for: subject)
        mug.receive_next_packet_as_message(socket)

        let state = State(ctx, subject, socket, <<>>)
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
  |> actor.named(ctx.session_name)
  |> actor.on_message(handle_message)
  |> actor.start()
}

fn connect(
  endpoint: Endpoint,
  identity: Identity,
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
