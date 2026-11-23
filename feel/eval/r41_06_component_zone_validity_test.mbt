///|
test "A component time rejects the same unknown named zones as a parsed time" {
  assert_eq(@eval.feel_eval("time(12,0,0,\"@Missing/Clock\")").text(), "null")
  assert_eq(@eval.feel_eval("time(\"12:00:00@Missing/Clock\")").text(), "null")
  assert_eq(
    @eval.feel_eval(
      "time(12,0,0,\"@Europe/Paris\") = time(\"12:00:00@Europe/Paris\")",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("time(12,0,0,\"+03:00\") = time(\"12:00:00+03:00\")").text(),
    "true",
  )
}
