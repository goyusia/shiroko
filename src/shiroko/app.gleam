import uptime/uptime
import dot_env/env
import logging
import mist
import shiroko/router
import wisp
import wisp/wisp_mist

pub fn start(wrap_reload) {
  logging.configure()
  logging.set_level(logging.Info)

  let _ = uptime.start()
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
