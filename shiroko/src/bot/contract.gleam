import gleam/erlang/process
import irc
import mug

pub type AdapterMessage {
  IncomingIrc(message: irc.Message)
  OutgoingText(channel: String, text: String)
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
    adapter_name: process.Name(AdapterMessage),
  )
}

pub type Error {
  ConnectionError(mug.ConnectError)
  SocketError(mug.Error)
  BotError(String)
}
