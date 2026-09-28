import irc
import mug

pub type Endpoint {
  IrcEndpoint(host: String, port: Int)
}

pub type Identity {
  IrcIdentity(nickname: String, realname: String)
}

pub type SessionMessage {
  SessionTcp(mug.TcpMessage)
  SessionIrcOutgoing(irc.Message)
  SessionIrcOutgoingBatch(List(irc.Message))
}
