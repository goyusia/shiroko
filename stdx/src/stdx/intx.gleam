import gleam/int
import gleam/string

pub fn pad_start(
  value: Int,
  to desired_length: Int,
  with pad: String,
) -> String {
  value
  |> int.to_string()
  |> string.pad_start(desired_length, pad)
}
