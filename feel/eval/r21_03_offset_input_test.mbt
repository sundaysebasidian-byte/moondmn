///|
test "The component time constructor consumes the entire textual offset" {
  assert_eq(@eval.feel_eval("time(10,1,0,\"+02:00tail\")").text(), "null")
  assert_eq(@eval.feel_eval("time(10,1,0,\"Z!\")").text(), "null")
  assert_eq(@eval.feel_eval("time(10,1,0,\"garbage\")").text(), "null")
  assert_eq(@eval.feel_eval("time(10,1,0,\"+02:00\")").text(), "10:01:00+02:00")
  assert_eq(@eval.feel_eval("time(10,1,0,\"Z\")").text(), "10:01:00Z")
  assert_eq(
    @eval.feel_eval("time(10,1,0,duration(\"PT1H\"))").text(),
    "10:01:00+01:00",
  )
}
