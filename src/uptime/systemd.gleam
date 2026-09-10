import gleam/json
import gleam/option
import shellout
import systemd_status

pub fn query_service(unit: String) -> systemd_status.Service {
  let #(command, arguments) = systemd_status.unit_property_list_command(unit)
  let assert Ok(output) = shellout.command(command, arguments, in: ".", opt: [])
  let assert Ok(service) = systemd_status.parse_service(output)
  service
}

fn service_type_to_string(service_type: systemd_status.ServiceType) -> String {
  case service_type {
    systemd_status.SimpleService -> "simple"
    systemd_status.OneshotService -> "oneshot"
    systemd_status.OtherServiceType(name) -> name
  }
}

fn load_state_to_string(load_state: systemd_status.LoadState) -> String {
  case load_state {
    systemd_status.Loaded -> "loaded"
    systemd_status.NotFound -> "not_found"
    systemd_status.BadSetting -> "bad_setting"
    systemd_status.LoadError -> "load_error"
    systemd_status.Masked -> "masked"
  }
}

fn active_state_to_string(active_state: systemd_status.ActiveState) -> String {
  case active_state {
    systemd_status.Active -> "active"
    systemd_status.Reloading -> "reloading"
    systemd_status.Inactive -> "inactive"
    systemd_status.Failed -> "failed"
    systemd_status.Activating -> "activating"
    systemd_status.Deactivating -> "deactivating"
  }
}

pub fn service_to_json(service: systemd_status.Service) -> json.Json {
  json.object([
    #("id", json.string(service.id)),
    #("type", json.string(service.type_ |> service_type_to_string)),
    #("load_state", json.string(service.load_state |> load_state_to_string)),
    #(
      "active_state",
      json.string(service.active_state |> active_state_to_string),
    ),
    #("sub_state", json.string(service.sub_state)),
    #("result", json.string(service.result)),
    #("description", json.string(option.unwrap(service.description, ""))),
    #("main_pid", json.int(option.unwrap(service.main_pid, 0))),
    #(
      "state_change_timestamp",
      json.nullable(service.state_change_timestamp, of: json.string),
    ),
    #(
      "active_enter_timestamp",
      json.nullable(service.active_enter_timestamp, of: json.string),
    ),
    #(
      "active_exit_timestamp",
      json.nullable(service.active_exit_timestamp, of: json.string),
    ),
    #(
      "inactive_enter_timestamp",
      json.nullable(service.inactive_enter_timestamp, of: json.string),
    ),
    #(
      "inactive_exit_timestamp",
      json.nullable(service.inactive_exit_timestamp, of: json.string),
    ),
  ])
}
