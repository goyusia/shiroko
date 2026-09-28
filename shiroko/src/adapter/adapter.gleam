import adapter/protocol
import bot/dispatcher
import gleam/erlang/process
import gleam/otp/actor
import irc
import irc/extension
import irc/outgoing
import irc/verb

type State {
  State(
    session_name: process.Name(protocol.SessionMessage),
    dispatcher_name: process.Name(dispatcher.Message),
  )
}

type Message =
  protocol.AdapterMessage

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    protocol.IncomingIrc(message) -> handle_incoming(state, message)
    protocol.OutgoingText(channel, text) ->
      handle_outgoing_text(state, channel, text)
  }
}

fn handle_incoming(
  state: State,
  message: irc.Message,
) -> actor.Next(State, Message) {
  case message.command {
    c if c == verb.privmsg -> handle_privmsg(state, message)
    c if c == verb.invite -> handle_invite(state, message)
    _ -> {
      actor.continue(state)
    }
  }
}

fn handle_outgoing_text(state: State, channel: String, text: String) {
  let messages = extension.encode_privmsg(channel, text)
  let session_subject = process.named_subject(state.session_name)
  process.send(session_subject, protocol.OutgoingIrcBatch(messages))

  actor.continue(state)
}

fn handle_privmsg(state: State, message: irc.Message) {
  case message.params {
    [channel, text] -> {
      process.send(
        process.named_subject(state.dispatcher_name),
        dispatcher.DispatcherText(channel, text),
      )
      actor.continue(state)
    }
    _ -> actor.continue(state)
  }
}

fn handle_invite(state: State, message: irc.Message) {
  case message.params {
    [_nickname, channel] -> {
      join(state, channel)
      actor.continue(state)
    }
    _ -> actor.continue(state)
  }
}

fn join(state: State, channel: String) {
  let session_subject = process.named_subject(state.session_name)
  outgoing.join(channel)
  |> protocol.OutgoingIrc()
  |> process.send(session_subject, _)
}

pub fn start_adapter(
  adapter_name: process.Name(protocol.AdapterMessage),
  session_name: process.Name(protocol.SessionMessage),
  dispatcher_name: process.Name(dispatcher.Message),
) {
  let initial = State(session_name, dispatcher_name)
  actor.new(initial)
  |> actor.named(adapter_name)
  |> actor.on_message(handle_message)
  |> actor.start
}
