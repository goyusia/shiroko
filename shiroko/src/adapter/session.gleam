import adapter/logger
import adapter/protocol.{type Endpoint, type Identity}
import gleam/bit_array
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import gleam/result
import gleam/set
import gleam/string
import irc
import irc/message
import irc/outgoing
import irc/reader
import irc/verb
import logging
import mug

type Message =
  protocol.SessionMessage

type State {
  State(
    socket: mug.Socket,
    buffer: BitArray,
    adapter_name: process.Name(protocol.AdapterMessage),
    logger: logger.Logger,
  )
}

type SessionError {
  ConnectionError(mug.ConnectError)
  SocketError(mug.Error)
  UnknownError(String)
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    protocol.IncomingTcp(mug.Packet(socket, packet)) -> {
      mug.receive_next_packet_as_message(socket)
      handle_packet(state, packet)
    }
    protocol.IncomingTcp(mug.SocketClosed(_socket)) -> {
      let reason = "socket closed"
      logging.log(logging.Warning, reason)
      actor.stop_abnormal(reason)
    }
    protocol.IncomingTcp(mug.TcpError(_socket, error)) -> {
      let reason = string.inspect(error)
      logging.log(logging.Critical, reason)
      actor.stop_abnormal(reason)
    }
    protocol.OutgoingIrc(message) -> {
      handle_irc_outgoing_single(state, message)
    }
    protocol.OutgoingIrcBatch(messages) -> {
      handle_irc_outgoing_bulk(state, messages)
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
    |> result.map_error(fn(e) { UnknownError(string.inspect(e)) }),
  )

  state.logger.received(line)

  case msg.command {
    "PING" -> {
      message.Message(..msg, command: verb.pong)
      |> fn(m) { send_bulk(state.socket, [m], state.logger.sent) }
    }
    _ -> {
      let subject = process.named_subject(state.adapter_name)
      process.send(subject, protocol.IncomingIrc(msg))
      Ok(Nil)
    }
  }
}

fn handle_irc_outgoing_single(
  state: State,
  message: irc.Message,
) -> actor.Next(State, Message) {
  let _ = send_bulk(state.socket, [message], state.logger.sent)
  actor.continue(state)
}

fn handle_irc_outgoing_bulk(
  state: State,
  messages: List(irc.Message),
) -> actor.Next(State, Message) {
  let _ = send_bulk(state.socket, messages, state.logger.sent)
  actor.continue(state)
}

pub fn supervised(endpoint, identity, session_name, adapter_name) {
  supervision.supervisor(fn() {
    start_supervisor(endpoint, identity, session_name, adapter_name)
  })
}

fn start_supervisor(
  endpoint: Endpoint,
  identity: Identity,
  session_name: process.Name(protocol.SessionMessage),
  adapter_name: process.Name(protocol.AdapterMessage),
) {
  let logger_name = process.new_name("logger")
  let logger_worker =
    supervision.worker(fn() { logger.start_logger(logger_name) })

  let session_worker =
    supervision.worker(fn() {
      start_session(endpoint, identity, session_name, adapter_name, logger_name)
    })

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(logger_worker)
  |> supervisor.add(session_worker)
  |> supervisor.start()
}

fn start_session(
  endpoint: Endpoint,
  identity: Identity,
  session_name: process.Name(protocol.SessionMessage),
  adapter_name: process.Name(protocol.AdapterMessage),
  logger_name: process.Name(logger.Message),
) {
  let logger = logger.logger_by_name(logger_name)

  actor.new_with_initialiser(1000, fn(subject) {
    case connect(endpoint, identity, logger) {
      Ok(socket) -> {
        let selector =
          process.new_selector()
          |> mug.select_tcp_messages(fn(msg) { protocol.IncomingTcp(msg) })
          |> process.select(for: subject)
        mug.receive_next_packet_as_message(socket)

        let state = State(socket, <<>>, adapter_name, logger)
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
  |> actor.named(session_name)
  |> actor.on_message(handle_message)
  |> actor.start()
}

fn connect(
  endpoint: Endpoint,
  identity: Identity,
  logger: logger.Logger,
) -> Result(mug.Socket, SessionError) {
  // TODO: 더 안정적힌 처리 방법?
  use socket <- result.try(
    mug.new(endpoint.host, endpoint.port)
    |> mug.timeout(milliseconds: 500)
    |> mug.connect()
    |> result.map_error(ConnectionError),
  )

  use _ <- result.try(flow_login(socket, identity, logger))
  Ok(socket)
}

fn send_bulk(
  socket: mug.Socket,
  messages: List(irc.Message),
  log: fn(String) -> Nil,
) -> Result(Nil, SessionError) {
  let lines = messages |> list.map(message.to_string)
  let retval =
    lines
    |> list.map(bit_array.from_string)
    |> list.fold(<<>>, fn(acc, x) {
      bit_array.concat([acc, x, <<"\r\n":utf8>>])
    })
    |> send_buffer_loop(send_socket(socket, _), _)

  case retval {
    Ok(_) -> list.each(lines, log)
    Error(_) -> Nil
  }

  retval
}

fn send_socket(
  socket: mug.Socket,
  data: BitArray,
) -> Result(Nil, SessionError) {
  mug.send(socket, data)
  |> result.map_error(SocketError)
}

fn send_buffer_loop(
  send: fn(BitArray) -> Result(Nil, SessionError),
  buffer: BitArray,
) -> Result(Nil, SessionError) {
  case bit_array.byte_size(buffer) {
    0 -> Ok(Nil)
    len if len > 512 -> {
      let assert Ok(first) = bit_array.slice(buffer, 0, 512)
      let assert Ok(rest) = bit_array.slice(buffer, 512, len - 512)
      send(first)
      |> result.try(fn(_) { send_buffer_loop(send, rest) })
    }
    _ -> {
      send(buffer)
    }
  }
}

fn receive_until_match(
  socket: mug.Socket,
  allowlist allowlist: set.Set(String),
  denylist denylist: set.Set(String),
  logger logger: logger.Logger,
) {
  receive_until_match_loop(socket, allowlist, denylist, <<>>, logger)
}

fn receive_until_match_loop(
  socket: mug.Socket,
  allowlist: set.Set(String),
  denylist: set.Set(String),
  buffer: BitArray,
  logger: logger.Logger,
) -> Result(Nil, SessionError) {
  use packet <- result.try(
    mug.receive(socket, timeout_milliseconds: 1000)
    |> result.map_error(SocketError),
  )

  let buffer = bit_array.append(buffer, packet)
  let #(lines, rest) = reader.extract_lines(buffer)

  case lines {
    [] -> receive_until_match_loop(socket, allowlist, denylist, rest, logger)
    [line, ..] -> {
      logger.received(line)

      let assert Ok(message) = message.parse(line)
      let allow = set.contains(allowlist, message.command)
      let deny = set.contains(denylist, message.command)
      case allow, deny {
        True, _ -> Ok(Nil)
        _, True -> Error(UnknownError(line))
        _, _ ->
          receive_until_match_loop(socket, allowlist, denylist, rest, logger)
      }
    }
  }
}

fn flow_login(socket: mug.Socket, identity: Identity, logger: logger.Logger) {
  let nickname = identity.nickname
  let realname = identity.realname

  let send = fn(message) { send_bulk(socket, [message], logger.sent) }
  use _ <- result.try(outgoing.nick(nickname) |> send)
  use _ <- result.try(outgoing.user(nickname, realname) |> send)
  use _ <- result.try(wait_until_welcome(socket, logger))
  Ok(Nil)
}

fn wait_until_welcome(socket: mug.Socket, logger: logger.Logger) {
  let allowlist = set.from_list([verb.rpl_welcome])
  let denylist = set.from_list([verb.err_nicknameinuse])
  receive_until_match(socket, allowlist:, denylist:, logger:)
}
