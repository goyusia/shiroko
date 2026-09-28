import gleam/erlang/process
import irc

pub type AdapterMessage {
  IncomingIrc(message: irc.Message)
  OutgoingText(room_id: String, text: String)
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
