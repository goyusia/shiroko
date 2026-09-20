// connection messages
pub const cap = "CAP"

pub const authenticate = "AUTHENTICATE"

pub const pass = "PASS"

pub const nick = "NICK"

pub const user = "USER"

pub const ping = "PING"

pub const pong = "PONG"

pub const oper = "OPER"

pub const quit = "QUIT"

pub const error = "ERROR"

// channel operations
pub const join = "JOIN"

pub const part = "PART"

pub const topic = "TOPIC"

pub const names = "NAMES"

pub const list = "LIST"

pub const invite = "INVITE"

pub const kick = "KICK"

// server queries and commands
pub const motd = "MOTD"

pub const version = "VERSION"

pub const admin = "AMDIN"

pub const connect = "CONNECT"

pub const lusers = "LUSERS"

pub const time = "TIME"

pub const stats = "STATS"

pub const help = "HELP"

pub const info = "INFO"

pub const mode = "MODE"

// sending messages
pub const privmsg = "PRIVMSG"

pub const notice = "NOTICE"

// user-based queries
pub const who = "WHO"

pub const whois = "WHOIS"

pub const whowas = "WHOWAS"

// operator messages
pub const kill = "kill"

pub const rehash = "REHASH"

pub const restart = "RESTART"

pub const squit = "SQUIT"

// optional messages
pub const away = "AWAY"

pub const links = "LINKS"

pub const userhost = "USERHOST"

pub const wallops = "WALLOPS"

// numerics
pub const rpl_welcome = "001"

pub const err_nicknameinuse = "433"
