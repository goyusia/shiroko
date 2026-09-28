import gleam/erlang/process

pub type Adapter {
  Adapter(send_text: fn(String, String) -> Nil)
}

pub type DispatcherMessage {
  DispatcherText(room_id: String, text: String)
}

pub type RoomMessage {
  RoomText(text: String)
}

pub type RoomStart {
  RoomStart(room_id: String, room_name: process.Name(RoomMessage))
}
