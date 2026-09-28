import gleam/string

pub fn split_byte_size(str: String, max_byte_size: Int) -> #(String, String) {
  split_byte_size_loop(str, max_byte_size, "")
}

fn split_byte_size_loop(
  str: String,
  max_byte_size: Int,
  acc: String,
) -> #(String, String) {
  case string.first(str) {
    Ok(head) -> {
      let rest = string.drop_start(str, 1)
      case string.byte_size(acc) + string.byte_size(head) {
        next_byte_size if next_byte_size > max_byte_size -> #(acc, str)
        _ -> split_byte_size_loop(rest, max_byte_size, acc <> head)
      }
    }
    Error(_) -> #(acc, "")
  }
}
