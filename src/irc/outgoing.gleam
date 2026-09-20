import irc
import irc/message
import irc/verb

pub fn join(channel: String) -> irc.Message {
  message.new(verb.join, [channel])
}

pub fn nick(nickname: String) -> irc.Message {
  message.new(verb.nick, [nickname])
}

pub fn user(username: String, realname: String) -> irc.Message {
  message.new(verb.user, [username, "0", "*", realname])
}

pub fn privmsg(dest: String, text: String) -> irc.Message {
  message.new(verb.privmsg, [dest, text])
}
