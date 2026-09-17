import bot
import dot_env as dot
import dot_env/env
import gleam/otp/static_supervisor as supervisor
import logging
import mist
import shiroko/router
import shiroko/web.{type Context}
import uptime.{type EndpointRegistry}
import wisp
import wisp/wisp_mist

pub fn start(wrap_reload, bot_config: bot.Config) {
  logging.configure()
  logging.set_level(logging.Info)

  dot.new()
  |> dot.set_debug(False)
  |> dot.load

  // let assert Ok(socket) =
  //   mug.new(host, port: port)
  //   |> mug.timeout(milliseconds: 500)
  //   |> mug.connect()

  let uptime_registry = new_uptime_registry()
  let context =
    web.Context(
      uptime_registry: uptime_registry,
      static_directory: static_directory(),
    )

  // TODO: supervisor 체제로는 아직 전환 안함
  bot.start(bot_config)

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(uptime.supervised(uptime_registry))
  |> supervisor.add(start_web(wrap_reload, context))
  |> supervisor.start()
}

fn start_web(wrap_reload, ctx: Context) {
  wisp.configure_logger()

  // Here we generate a secret key, but in a real application you would want to
  // load this from somewhere so that it is not regenerated on every restart.
  let secret_key_base = wisp.random_string(64)

  let host = env.get_string_or("SHIROKO_HOST", "0.0.0.0")
  let port = env.get_int_or("SHIROKO_PORT", 5161)

  let handler = router.handle_request(_, ctx)

  handler
  |> wisp_mist.handler(secret_key_base)
  |> wrap_reload()
  |> mist.new
  |> mist.bind(host)
  |> mist.port(port)
  |> mist.supervised()
}

pub fn static_directory() -> String {
  // The priv directory is where we store non-Gleam and non-Erlang files,
  // including static assets to be served.
  // This function returns an absolute path and works both in development and in
  // production after compilation.
  let assert Ok(priv_directory) = wisp.priv_directory("shiroko")
  priv_directory <> "/static"
}

fn new_uptime_registry() -> EndpointRegistry {
  let host = "http://ichika"
  // let host = "http://127.0.0.1"
  let interval = 60_000

  let endpoints = [
    uptime.http("nginx", host, interval),
    uptime.http("pi-hole", host <> ":8089/admin/", interval),
    uptime.http("calibre", host <> ":8083/login", interval),
    uptime.http("dagu", host <> ":8525/login", interval),
  ]
  uptime.new(endpoints)
}
