///|
test "Text endpoints in range strings use FEEL literal escape rules" {
  assert_eq(
    @eval.feel_eval("range(\"[\\\"a\\\\tb\\\"..\\\"z\\\"]\").start").text(),
    "a\tb",
  )
  assert_eq(
    @eval.feel_eval("range(\"[\\\"a\\\\\\\"b\\\"..\\\"z\\\"]\").start").text(),
    "a\"b",
  )
  assert_eq(
    @eval.feel_eval("range(\"[\\\"\\\\u0061\\\"..\\\"z\\\"]\").start").text(),
    "a",
  )
  assert_eq(
    @eval.feel_eval("range(\"[\\\"a\\\" + \\\"b\\\"..\\\"z\\\"]\")").text(),
    "null",
  )
  assert_eq(
    @eval.feel_eval("range(\"[\\\"😀a\\\"..\\\"😀z\\\"]\").end").text(),
    "😀z",
  )
}
