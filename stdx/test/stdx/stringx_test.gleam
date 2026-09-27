import stdx/stringx

pub fn split_byte_size_empty_test() {
  assert stringx.split_byte_size("", 10) == Error(Nil)
}

pub fn split_byte_size_ascii_test() {
  assert stringx.split_byte_size("abcdef", 2) == Ok(#("ab", "cdef"))
  assert stringx.split_byte_size("abcdef", 6) == Ok(#("abcdef", ""))
  assert stringx.split_byte_size("abcdef", 7) == Ok(#("abcdef", ""))
}

pub fn split_byte_size_utf8_hangul_test() {
  assert stringx.split_byte_size("ab한글cd", 3) == Ok(#("ab", "한글cd"))
  assert stringx.split_byte_size("ab한글cd", 4) == Ok(#("ab", "한글cd"))
  assert stringx.split_byte_size("ab한글cd", 5) == Ok(#("ab한", "글cd"))
  assert stringx.split_byte_size("ab한글cd", 6) == Ok(#("ab한", "글cd"))
  assert stringx.split_byte_size("ab한글cd", 7) == Ok(#("ab한", "글cd"))
  assert stringx.split_byte_size("ab한글cd", 8) == Ok(#("ab한글", "cd"))
  assert stringx.split_byte_size("ab한글cd", 9) == Ok(#("ab한글c", "d"))
}
