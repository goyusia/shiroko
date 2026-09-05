import logging
import mist
import shiroko/discord
import shiroko/router
import wisp
import wisp/wisp_mist

pub fn start(wrap_reload) {
  logging.configure()
  logging.set_level(logging.Info)

  let _ = start_web(wrap_reload)
  let _ = discord.start_bot()
}

fn start_web(wrap_reload) {
  wisp.configure_logger()

  // Here we generate a secret key, but in a real application you would want to
  // load this from somewhere so that it is not regenerated on every restart.
  let secret_key_base = wisp.random_string(64)

  // Start the Mist web server.
  wisp_mist.handler(router.handle_request, secret_key_base)
  |> wrap_reload()
  |> mist.new
  |> mist.bind("0.0.0.0")
  |> mist.port(8000)
  |> mist.start
}
