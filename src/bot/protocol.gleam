import gleam/erlang/process
import irc
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

pub type RouterMessage {
  RouterMessage(dest: String, text: String)
}

pub type ChannelMessage {
  ChannelMessage(text: String)
}

pub type ChannelStart {
  ChannelStart(channel: String, name: process.Name(ChannelMessage), link: Link)
}

pub type Link {
  Link(
    session: process.Name(SessionMessage),
    client: process.Name(ClientMessage),
    router: process.Name(RouterMessage),
  )
}

pub fn client_subject(link: Link) {
  process.named_subject(link.client)
}

pub fn session_subject(link: Link) {
  process.named_subject(link.session)
}

pub type Error {
  ConnectionError(mug.ConnectError)
  SocketError(mug.Error)
  BotError(String)
}
