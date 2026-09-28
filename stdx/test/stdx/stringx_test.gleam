import stdx/stringx

pub fn split_byte_size_empty_test() {
  assert stringx.split_byte_size("", 10) == #("", "")
}

pub fn split_byte_size_ascii_test() {
  assert stringx.split_byte_size("abcdef", 2) == #("ab", "cdef")
  assert stringx.split_byte_size("abcdef", 6) == #("abcdef", "")
  assert stringx.split_byte_size("abcdef", 7) == #("abcdef", "")
}

pub fn split_byte_size_utf8_hangul_test() {
  assert stringx.split_byte_size("ab한글cd", 3) == #("ab", "한글cd")
  assert stringx.split_byte_size("ab한글cd", 4) == #("ab", "한글cd")
  assert stringx.split_byte_size("ab한글cd", 5) == #("ab한", "글cd")
  assert stringx.split_byte_size("ab한글cd", 6) == #("ab한", "글cd")
  assert stringx.split_byte_size("ab한글cd", 7) == #("ab한", "글cd")
  assert stringx.split_byte_size("ab한글cd", 8) == #("ab한글", "cd")
  assert stringx.split_byte_size("ab한글cd", 9) == #("ab한글c", "d")
}
