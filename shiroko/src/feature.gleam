import bot/job
import feature/counter
import feature/crash
import feature/ops
import feature/ping
import feature/ps
import feature/version
import gleam/erlang/process

pub fn create_simple_handler(argv: List(String)) {
  case argv {
    ["!ping", ..args] -> Ok(ping.execute_ping(args, _))
    ["!crash", ..args] -> Ok(crash.execute_crash(args, _))
    ["!uptime", ..args] -> Ok(ops.execute_uptime(args, _))
    ["!version", ..args] -> Ok(version.execute_version(args, _))
    ["!ops.deploy", ..args] -> Ok(ops.execute_deploy(args, _))
    ["!ops.restart", ..args] -> Ok(ops.execute_restart(args, _))
    _ -> Error(Nil)
  }
}

pub fn create_counter_handler(argv: List(String), state: counter.State) {
  case argv {
    ["!counter.show", ..args] -> Ok(counter.execute_show(state, args, _))
    ["!counter.add", ..args] -> Ok(counter.execute_add(state, args, _))
    ["!counter.reset", ..args] -> Ok(counter.execute_reset(state, args, _))
    _ -> Error(Nil)
  }
}

pub fn create_ps_handler(
  argv: List(String),
  job_registry: process.Subject(job.Message),
) {
  case argv {
    ["!ps.list", ..args] -> Ok(ps.execute_list(args, job_registry, _))
    ["!ps.get", ..args] -> Ok(ps.execute_get(args, job_registry, _))
    _ -> Error(Nil)
  }
}
