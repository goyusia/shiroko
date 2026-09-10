import dot_env/env
import logging
import mist
import shiroko/router
import uptime/uptime
import wisp
import wisp/wisp_mist

pub fn start(wrap_reload) {
  logging.configure()
  logging.set_level(logging.Info)

  let _ = start_uptime()
  let _ = start_web(wrap_reload)
}

fn start_web(wrap_reload) {
  wisp.configure_logger()

  // Here we generate a secret key, but in a real application you would want to
  // load this from somewhere so that it is not regenerated on every restart.
  let secret_key_base = wisp.random_string(64)

  let host = env.get_string_or("SHIROKO_HOST", "0.0.0.0")
  let port = env.get_int_or("SHIROKO_PORT", 5161)

  // Start the Mist web server.
  wisp_mist.handler(router.handle_request, secret_key_base)
  |> wrap_reload()
  |> mist.new
  |> mist.bind(host)
  |> mist.port(port)
  |> mist.start
}

fn start_uptime() {
  let host = "http://ichika"
  // let host = "http://127.0.0.1"
  let interval = 60_000

  let probes = [
    uptime.Probe(name: "nginx", url: host, interval:),
    uptime.Probe(name: "Pi-hole Admin", url: host <> ":8089/admin/", interval:),
    uptime.Probe(name: "calibre", url: host <> ":8083/login", interval:),
    uptime.Probe(name: "dagu", url: host <> ":8525/login", interval:),
  ]
  uptime.start(probes)
}
