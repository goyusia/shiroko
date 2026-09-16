import gleam/erlang/process
import irc/loop
import irc/wire
import mug

pub fn start() {
  let _ = process.spawn_unlinked(run)
}

fn run() {
  let host = "ichika"
  let port = 6667

  let nickname = "shiroko"
  let realname = "shiroko"
  let channel = "#shiroko"

  let assert Ok(socket) =
    mug.new(host, port: port)
    |> mug.timeout(milliseconds: 500)
    |> mug.connect()

  let ctx = loop.Context(socket)
  let send = loop.send_message(ctx, _)

  assert wire.nick(nickname) |> send == Ok(Nil)
  assert wire.user(nickname, realname) |> send == Ok(Nil)
  assert wire.join(channel) |> send == Ok(Nil)

  let selector =
    process.new_selector()
    |> mug.select_tcp_messages(fn(msg) { msg })

  mug.receive_next_packet_as_message(socket)
  loop.receive_loop(selector, <<>>)
}
