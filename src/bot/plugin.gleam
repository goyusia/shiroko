import irc
import irc/message
import irc/tag
import mug

pub type Sender {
  Sender(respond: fn(irc.Message) -> Result(Nil, mug.Error))
}

fn privmsg(channel: String, text: String) -> irc.Message {
  message.Message(
    command: "PRIVMSG",
    params: [channel, text],
    source: message.NoSource,
    tags: tag.new_tags(),
  )
}

pub fn dispatch(msg: message.Message, sender: Sender) {
  case msg.params {
    [_, "!ping"] -> handle_ping(msg, sender)
    [_, "!" <> _rest] -> handle_unknown(msg, sender)
    _ -> Ok(Nil)
  }
}

fn handle_ping(msg: message.Message, sender: Sender) {
  case msg.params {
    [channel, ..] -> {
      let reply = privmsg(channel, "pong")
      sender.respond(reply)
    }
    _ -> Ok(Nil)
  }
}

fn handle_unknown(msg: message.Message, sender: Sender) {
  case msg.params {
    [channel, first, ..] -> {
      let text = "unknown command: " <> first
      let reply = privmsg(channel, text)
      sender.respond(reply)
    }
    _ -> Ok(Nil)
  }
}
