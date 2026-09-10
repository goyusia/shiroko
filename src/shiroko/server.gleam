import dot_env as dot
import dot_env/env
import gleam/otp/static_supervisor as supervisor
import logging
import mist
import shiroko/router
import uptime/uptime
import wisp
import wisp/wisp_mist

pub fn start(wrap_reload) {
  logging.configure()
  logging.set_level(logging.Info)

  dot.new()
  |> dot.set_debug(False)
  |> dot.load

  let uptime_service = new_uptime()

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(uptime.supervised(uptime_service))
  |> supervisor.add(start_web(wrap_reload, uptime_service))
  |> supervisor.start()
}

fn start_web(wrap_reload, uptime_registry: uptime.EndpointRegistry) {
  wisp.configure_logger()

  // Here we generate a secret key, but in a real application you would want to
  // load this from somewhere so that it is not regenerated on every restart.
  let secret_key_base = wisp.random_string(64)

  let host = env.get_string_or("SHIROKO_HOST", "0.0.0.0")
  let port = env.get_int_or("SHIROKO_PORT", 5161)

  wisp_mist.handler(
    fn(req) { router.handle_request(uptime_registry, req) },
    secret_key_base,
  )
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
