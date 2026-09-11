import dot_env as dot
import dot_env/env
import gleam/otp/static_supervisor as supervisor
import logging
import mist
import shiroko/router
import shiroko/web
import uptime/uptime
import wisp
import wisp/wisp_mist

pub fn start(wrap_reload) {
  logging.configure()
  logging.set_level(logging.Info)

  dot.new()
  |> dot.set_debug(False)
  |> dot.load

  let uptime_registry = new_uptime()
  let context = web.Context(uptime_registry:)

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(uptime.supervised(uptime_registry))
  |> supervisor.add(start_web(wrap_reload, context))
  |> supervisor.start()
}

fn start_web(wrap_reload, context: web.Context) {
  wisp.configure_logger()

  // Here we generate a secret key, but in a real application you would want to
  // load this from somewhere so that it is not regenerated on every restart.
  let secret_key_base = wisp.random_string(64)

  let host = env.get_string_or("SHIROKO_HOST", "0.0.0.0")
  let port = env.get_int_or("SHIROKO_PORT", 5161)

  let handler = router.handle_request(_, context)

  handler
  |> wisp_mist.handler(secret_key_base)
  |> wrap_reload()
  |> mist.new
  |> mist.bind(host)
  |> mist.port(port)
  |> mist.supervised()
}

fn new_uptime() -> uptime.EndpointRegistry {
  let host = "http://ichika"
  // let host = "http://127.0.0.1"
  let interval = 60_000

  let endpoints = [
    uptime.Http(name: "nginx", url: host, interval: interval),
    uptime.Http(
      name: "pi-hole",
      url: host <> ":8089/admin/",
      interval: interval,
    ),
    uptime.Http(name: "calibre", url: host <> ":8083/login", interval: interval),
    uptime.Http(name: "dagu", url: host <> ":8525/login", interval: interval),
  ]
  uptime.new(endpoints)
}
