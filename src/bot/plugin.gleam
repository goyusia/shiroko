import irc
import irc/message
import irc/tag

pub type Sender {
  Sender(respond: fn(irc.Message) -> Nil)
}

fn privmsg(channel: String, text: String) -> irc.Message {
  message.Message(
    command: "PRIVMSG",
    params: [channel, text],
    source: message.NoSource,
    tags: tag.new(),
  )
}

pub fn dispatch(msg: message.Message, sender: Sender) {
  case msg.params {
    [_, "!ping"] -> handle_ping(msg, sender)
    [_, "!" <> _rest] -> handle_unknown(msg, sender)
    _ -> Nil
  }
}

fn handle_ping(msg: message.Message, sender: Sender) {
  case msg.params {
    [channel, ..] -> {
      let reply = privmsg(channel, "pong")
      sender.respond(reply)
    }
    _ -> Nil
  }
}

fn handle_unknown(msg: message.Message, sender: Sender) {
  case msg.params {
    [channel, first, ..] -> {
      let text = "unknown command: " <> first
      let reply = privmsg(channel, text)
      sender.respond(reply)
    }
    _ -> Nil
  }
}
