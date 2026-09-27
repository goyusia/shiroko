import bot/irc_logger
import bot/protocol.{type Endpoint, type Identity}
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
    client_name: process.Name(protocol.ClientMessage),
    logger_name: process.Name(irc_logger.Message),
  )
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    protocol.SessionTcp(mug.Packet(socket, packet)) -> {
      mug.receive_next_packet_as_message(socket)
      handle_packet(state, packet)
    }
    protocol.SessionTcp(mug.SocketClosed(_socket)) -> {
      let reason = "socket closed"
      logging.log(logging.Warning, reason)
      actor.stop_abnormal(reason)
    }
    protocol.SessionTcp(mug.TcpError(_socket, error)) -> {
      let reason = string.inspect(error)
      logging.log(logging.Critical, reason)
      actor.stop_abnormal(reason)
    }
    protocol.SessionIrcOutgoing(message) -> {
      handle_irc_outgoing_single(state, message)
    }
    protocol.SessionIrcOutgoingBatch(messages) -> {
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
    |> result.map_error(fn(e) { protocol.BotError(string.inspect(e)) }),
  )

  let log_sent = irc_logger.sent_fun(state.logger_name)
  let log_received = irc_logger.received_fun(state.logger_name)
  log_received(msg, line)

  case msg.command {
    "PING" -> {
      message.Message(..msg, command: verb.pong)
      |> send_single(state.socket, _, log_sent)
    }
    _ -> {
      let subject = process.named_subject(state.client_name)
      process.send(subject, protocol.ClientIncoming(msg))
      Ok(Nil)
    }
  }
}

fn handle_irc_outgoing_single(
  state: State,
  message: irc.Message,
) -> actor.Next(State, Message) {
  let log_sent = irc_logger.sent_fun(state.logger_name)
  let _ = send_single(state.socket, message, log_sent)
  actor.continue(state)
}

fn handle_irc_outgoing_bulk(
  state: State,
  messages: List(irc.Message),
) -> actor.Next(State, Message) {
  let log_sent = irc_logger.sent_fun(state.logger_name)
  let _ = send_bulk(state.socket, messages, log_sent)
  actor.continue(state)
}

pub fn supervised(config, session_name, client_name) {
  supervision.supervisor(fn() {
    start_supervisor(config, session_name, client_name)
  })
}

fn start_supervisor(
  config: protocol.Config,
  session_name: process.Name(protocol.SessionMessage),
  client_name: process.Name(protocol.ClientMessage),
) {
  let logger_name = process.new_name("irc_logger")
  let logger_worker =
    supervision.worker(fn() { irc_logger.start_logger(logger_name) })

  let session_worker =
    supervision.worker(fn() {
      start_session(config, session_name, client_name, logger_name)
    })

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(logger_worker)
  |> supervisor.add(session_worker)
  |> supervisor.start()
}

pub fn start_session(
  config: protocol.Config,
  session_name: process.Name(protocol.SessionMessage),
  client_name: process.Name(protocol.ClientMessage),
  logger_name: process.Name(irc_logger.Message),
) {
  actor.new_with_initialiser(1000, fn(subject) {
    case connect(config.endpoint, config.identity) {
      Ok(socket) -> {
        let selector =
          process.new_selector()
          |> mug.select_tcp_messages(fn(msg) { protocol.SessionTcp(msg) })
          |> process.select(for: subject)
        mug.receive_next_packet_as_message(socket)

        let state = State(socket, <<>>, client_name, logger_name)
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
) -> Result(mug.Socket, protocol.Error) {
  // TODO: 더 안정적힌 처리 방법?
  use socket <- result.try(
    mug.new(endpoint.host, endpoint.port)
    |> mug.timeout(milliseconds: 500)
    |> mug.connect()
    |> result.map_error(protocol.ConnectionError),
  )

  use _ <- result.try(flow_login(socket, identity))
  Ok(socket)
}

fn send_single(
  socket: mug.Socket,
  msg: irc.Message,
  log: fn(irc.Message, String) -> Nil,
) -> Result(Nil, protocol.Error) {
  let line = msg |> message.to_string()
  let retval =
    line
    |> bit_array.from_string()
    |> fn(x) { bit_array.concat([x, <<"\r\n":utf8>>]) }
    |> send_buffer_loop(send_socket(socket, _), _)

  log(msg, line)
  retval
}

fn send_bulk(
  socket: mug.Socket,
  messages: List(irc.Message),
  log: fn(irc.Message, String) -> Nil,
) -> Result(Nil, protocol.Error) {
  let lines = messages |> list.map(message.to_string)
  let retval =
    lines
    |> list.map(bit_array.from_string)
    |> list.fold(<<>>, fn(acc, x) {
      bit_array.concat([acc, x, <<"\r\n":utf8>>])
    })
    |> send_buffer_loop(send_socket(socket, _), _)

  list.strict_zip(messages, lines)
  |> result.unwrap([])
  |> list.each(fn(tuple) {
    let #(message, line) = tuple
    log(message, line)
  })

  retval
}

fn send_socket(
  socket: mug.Socket,
  data: BitArray,
) -> Result(Nil, protocol.Error) {
  mug.send(socket, data)
  |> result.map_error(protocol.SocketError)
}

fn send_buffer_loop(
  send: fn(BitArray) -> Result(Nil, protocol.Error),
  buffer: BitArray,
) -> Result(Nil, protocol.Error) {
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
) {
  receive_until_match_inner(socket, allowlist, denylist, <<>>)
}

fn receive_until_match_inner(
  socket: mug.Socket,
  allowlist: set.Set(String),
  denylist: set.Set(String),
  buffer: BitArray,
) -> Result(Nil, protocol.Error) {
  use packet <- result.try(
    mug.receive(socket, timeout_milliseconds: 1000)
    |> result.map_error(protocol.SocketError),
  )

  let buffer = bit_array.append(buffer, packet)
  let #(lines, rest) = reader.extract_lines(buffer)

  case lines {
    [] -> receive_until_match_inner(socket, allowlist, denylist, rest)
    [line, ..] -> {
      logging.log(logging.Debug, line)

      let assert Ok(message) = message.parse(line)
      let allow = set.contains(allowlist, message.command)
      let deny = set.contains(denylist, message.command)
      case allow, deny {
        True, _ -> Ok(Nil)
        _, True -> Error(protocol.BotError(line))
        _, _ -> receive_until_match_inner(socket, allowlist, denylist, rest)
      }
    }
  }
}

fn flow_login(socket: mug.Socket, identity: Identity) {
  let nickname = identity.nickname
  let realname = identity.realname

  let send = send_single(socket, _, fn(_, _) { Nil })
  use _ <- result.try(outgoing.nick(nickname) |> send)
  use _ <- result.try(outgoing.user(nickname, realname) |> send)
  use _ <- result.try(wait_until_welcome(socket))
  Ok(Nil)
}

fn wait_until_welcome(socket: mug.Socket) {
  let allowlist = set.from_list([verb.rpl_welcome])
  let denylist = set.from_list([verb.err_nicknameinuse])
  receive_until_match(socket, allowlist:, denylist:)
}
