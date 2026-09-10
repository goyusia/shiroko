import dot_env as dot
import dot_env/env
import gleam/erlang/process
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

  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(start_uptime())
  |> supervisor.add(start_web(wrap_reload))
  |> supervisor.start()
}

fn start_web(wrap_reload) {
  wisp.configure_logger()

  // Here we generate a secret key, but in a real application you would want to
  // load this from somewhere so that it is not regenerated on every restart.
  let secret_key_base = wisp.random_string(64)

  let host = env.get_string_or("SHIROKO_HOST", "0.0.0.0")
  let port = env.get_int_or("SHIROKO_PORT", 5161)

  wisp_mist.handler(router.handle_request, secret_key_base)
  |> wrap_reload()
  |> mist.new
  |> mist.bind(host)
  |> mist.port(port)
  |> mist.supervised()
}

fn start_uptime() {
  let host = "http://ichika"
  // let host = "http://127.0.0.1"
  let interval = 60_000

  let nginx = process.new_name("uptime_nginx")
  let nginx_probe =
    uptime.Probe(
      name: "nginx",
      url: host,
      interval: interval,
      worker_name: nginx,
    )

  let pi_hole = process.new_name("uptime_pi_hole")
  let pi_hole_probe =
    uptime.Probe(
      name: "Pi-hole Admin",
      url: host <> ":8089/admin/",
      interval: interval,
      worker_name: pi_hole,
    )

  let calibre = process.new_name("uptime_calibre")
  let calibre_probe =
    uptime.Probe(
      name: "calibre",
      url: host <> ":8083/login",
      interval: interval,
      worker_name: calibre,
    )

  let dagu = process.new_name("uptime_dagu")
  let dagu_probe =
    uptime.Probe(
      name: "dagu",
      url: host <> ":8525/login",
      interval: interval,
      worker_name: dagu,
    )

  let supervisor_name = process.new_name("uptime")
  uptime.supervised(
    [nginx_probe, pi_hole_probe, calibre_probe, dagu_probe],
    supervisor_name,
  )
}
