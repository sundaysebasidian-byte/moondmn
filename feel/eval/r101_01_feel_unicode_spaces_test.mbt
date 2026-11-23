///|
test "FEEL grammar whitespace works inside and between tokens" {
  assert_eq(@eval.feel_eval("1 + 2").text(), "3")
  assert_eq(
    @eval.feel_eval("date and time(\"2024-02-29T10:15:00\").year").text(),
    "2024",
  )
  assert_eq(@eval.feel_eval("﻿1 +​2").text(), "3")
  assert_eq(@eval.feel_eval("string length(\"a b\")").text(), "3")
  assert_eq(@eval.feel_eval("1 +᠎2").text(), "3")
  assert_eq(@eval.feel_eval("1+　2").text(), "3")
  assert_eq(
    @eval.feel_eval("{value:3, check: value +᠎1}.check").text(),
    "4",
  )
  assert_eq(
    @eval.feel_eval("date　andtime(\"2024-02-29T10:15:00\").year").text(),
    "2024",
  )
}
