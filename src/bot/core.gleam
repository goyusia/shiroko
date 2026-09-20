import gleam/bit_array
import gleam/erlang/process
import gleam/result
import gleam/set
import irc
import irc/message
import irc/outgoing
import irc/reader
import logging
import mug

pub type Endpoint {
  IrcEndpoint(host: String, port: Int)
}

pub type Identity {
  IrcIdentity(nickname: String, realname: String)
}

pub type Config {
  Config(endpoint: Endpoint, identity: Identity, channels: List(String))
}

pub type SessionMessage {
  Tcp(mug.TcpMessage)
  IrcOutgoing(irc.Message)
}

pub type ClientMessage {
  ClientMessage(message: irc.Message, line: String)
}

pub type Context {
  Context(
    session_name: process.Name(SessionMessage),
    client_name: process.Name(ClientMessage),
  )
}

pub fn client_subject(ctx: Context) {
  process.named_subject(ctx.client_name)
}

pub fn session_subject(ctx: Context) {
  process.named_subject(ctx.session_name)
}

pub type Error {
  ConnectionError(mug.ConnectError)
  SocketError(mug.Error)
  BotError(String)
}

pub fn send_single(socket: mug.Socket, msg: irc.Message) -> Result(Nil, Error) {
  msg
  |> message.to_string()
  |> bit_array.from_string()
  |> fn(x) { bit_array.concat([x, <<"\r\n":utf8>>]) }
  |> mug.send(socket, _)
  |> result.map_error(SocketError)
}

pub fn send_line(
  socket: mug.Socket,
  dest: String,
  line: String,
) -> Result(Nil, Error) {
  outgoing.privmsg(dest, line)
  |> send_single(socket, _)
}

pub fn receive_until_match(
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
) -> Result(Nil, Error) {
  use packet <- result.try(
    mug.receive(socket, timeout_milliseconds: 1000)
    |> result.map_error(SocketError),
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
        _, True -> Error(BotError(line))
        _, _ -> receive_until_match_inner(socket, allowlist, denylist, rest)
      }
    }
  }
}
