import feature/counter
import feature/crash
import feature/ops
import feature/ping
import feature/version

pub fn create_simple_handler(tokens: List(String)) {
  case tokens {
    ["!ping", ..argv] -> Ok(ping.execute_ping(argv, _))
    ["!crash", ..argv] -> Ok(crash.execute_crash(argv, _))
    ["!uptime", ..argv] -> Ok(ops.execute_uptime(argv, _))
    ["!version", ..argv] -> Ok(version.execute_version(argv, _))
    ["!ops.deploy", ..argv] -> Ok(ops.execute_deploy(argv, _))
    ["!ops.restart", ..argv] -> Ok(ops.execute_restart(argv, _))
    _ -> Error(Nil)
  }
}

pub fn create_counter_handler(tokens: List(String), state: counter.State) {
  case tokens {
    ["!counter.show", ..argv] -> Ok(counter.execute_show(state, argv, _))
    ["!counter.add", ..argv] -> Ok(counter.execute_add(state, argv, _))
    ["!counter.reset", ..argv] -> Ok(counter.execute_reset(state, argv, _))
    _ -> Error(Nil)
  }
}
