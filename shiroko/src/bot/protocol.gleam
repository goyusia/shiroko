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
  SessionTcp(mug.TcpMessage)
  SessionIrcOutgoing(irc.Message)
  SessionIrcOutgoingBatch(List(irc.Message))
}

pub type ClientMessage {
  ClientIncoming(message: irc.Message, line: String)
  ClientOutgoingText(channel: String, text: String)
}

pub type DispatcherMessage {
  DispatcherText(channel: String, text: String)
}

pub type ChannelMessage {
  ChannelText(text: String)
}

pub type ChannelStart {
  ChannelStart(
    channel: String,
    channel_name: process.Name(ChannelMessage),
    client_name: process.Name(ClientMessage),
  )
}

pub type Error {
  ConnectionError(mug.ConnectError)
  SocketError(mug.Error)
  BotError(String)
}
