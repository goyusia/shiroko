import bot/protocol.{type Endpoint, type Identity}
import gleam/bit_array
import gleam/erlang/process
import gleam/list
import gleam/otp/actor
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
  State(link: protocol.Link, socket: mug.Socket, buffer: BitArray)
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    protocol.Tcp(mug.Packet(socket, packet)) -> {
      mug.receive_next_packet_as_message(socket)
      handle_packet(state, packet)
    }
    protocol.Tcp(mug.SocketClosed(_socket)) -> {
      let reason = "socket closed"
      logging.log(logging.Warning, reason)
      actor.stop_abnormal(reason)
    }
    protocol.Tcp(mug.TcpError(_socket, error)) -> {
      let reason = string.inspect(error)
      logging.log(logging.Critical, reason)
      actor.stop_abnormal(reason)
    }
    protocol.IrcOutgoing(message) -> {
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
    |> result.map_error(fn(e) { protocol.BotError(string.inspect(e)) }),
  )

  case msg.command {
    "PING" -> {
      message.Message(..msg, command: verb.pong)
      |> send_single(state.socket, _)
    }
    _ -> {
      let subject = protocol.client_subject(state.link)
      process.send(subject, protocol.ClientMessage(msg, line))
      Ok(Nil)
    }
  }
}

fn handle_irc_outgoing(
  state: State,
  message: irc.Message,
) -> actor.Next(State, Message) {
  let _ = send_single(state.socket, message)
  actor.continue(state)
}

pub fn start(config: protocol.Config, link: protocol.Link) {
  actor.new_with_initialiser(1000, fn(subject) {
    case connect(config.endpoint, config.identity) {
      Ok(socket) -> {
        let selector =
          process.new_selector()
          |> mug.select_tcp_messages(fn(msg) { protocol.Tcp(msg) })
          |> process.select(for: subject)
        mug.receive_next_packet_as_message(socket)

        let state = State(link, socket, <<>>)
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
  |> actor.named(link.session)
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

pub fn send_single(
  socket: mug.Socket,
  msg: irc.Message,
) -> Result(Nil, protocol.Error) {
  msg
  |> message.to_string()
  |> bit_array.from_string()
  |> fn(x) { bit_array.concat([x, <<"\r\n":utf8>>]) }
  |> mug.send(socket, _)
  |> result.map_error(protocol.SocketError)
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

  let send = send_single(socket, _)
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
