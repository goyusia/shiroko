import gleam/erlang/process
import irc
import mug

pub type AdapterMessage {
  IncomingIrc(message: irc.Message)
  OutgoingText(channel: String, text: String)
}

pub type DispatcherMessage {
  DispatcherText(room_id: String, text: String)
}

pub type RoomMessage {
  RoomText(text: String)
}

pub type RoomStart {
  RoomStart(
    room_id: String,
    room_name: process.Name(RoomMessage),
    adapter_name: process.Name(AdapterMessage),
  )
}

pub type Error {
  ConnectionError(mug.ConnectError)
  SocketError(mug.Error)
  BotError(String)
}
