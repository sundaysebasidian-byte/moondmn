///|
test "Range strings ignore the double dot inside quoted endpoints" {
  assert_eq(
    @eval.feel_eval("range(\"[\\\"a..c\\\"..\\\"z\\\"]\").start").text(),
    "a..c",
  )
  assert_eq(
    @eval.feel_eval("range(\"[\\\"😀..a\\\"..\\\"😀..z\\\"]\").end").text(),
    "😀..z",
  )
  assert_eq(
    @eval.feel_eval("range(\"[\\\"a\\\"..\\\"z..x\\\"]\").end").text(),
    "z..x",
  )
  assert_eq(@eval.feel_eval("range(\"[1..3]\").end").text(), "3")
  assert_eq(@eval.feel_eval("range(\"(..2]\").start").text(), "null")
  assert_eq(
    @eval.feel_eval("range(\"[\\\"a\\\\\\\\\\\\\\\"..b\\\"..\\\"z\\\"]\").end").text(),
    "z",
  )
  assert_eq(
    @eval.feel_eval("range(\"[@\\\"2024-01-02\\\"..@\\\"2024-01-04\\\"]\").end").text(),
    "2024-01-04",
  )
}
