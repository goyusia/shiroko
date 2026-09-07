import shellout
import systemd_status

pub fn query_service(unit: String) -> systemd_status.Service {
  let #(command, arguments) = systemd_status.unit_property_list_command(unit)
  let assert Ok(output) = shellout.command(command, arguments, in: ".", opt: [])
  let assert Ok(service) = systemd_status.parse_service(output)
  service
}
