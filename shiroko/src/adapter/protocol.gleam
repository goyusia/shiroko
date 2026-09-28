import irc
import mug

pub type Endpoint {
  IrcEndpoint(host: String, port: Int)
}

pub type Identity {
  IrcIdentity(nickname: String, realname: String)
}

pub type SessionMessage {
  IncomingTcp(mug.TcpMessage)
  OutgoingIrc(irc.Message)
  OutgoingIrcBatch(List(irc.Message))
}

pub type AdapterMessage {
  IncomingIrc(message: irc.Message)
  OutgoingText(room_id: String, text: String)
}
