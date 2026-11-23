///|
test "Date and time constructors reject fractional calendar or clock components" {
  assert_eq(@eval.feel_eval("date(2024,1.5,1)").text(), "null")
  assert_eq(@eval.feel_eval("date(2024,1,1.75)").text(), "null")
  assert_eq(@eval.feel_eval("date(2024.2,1,1)").text(), "null")
  assert_eq(@eval.feel_eval("time(10.25,0,0)").text(), "null")
  assert_eq(@eval.feel_eval("time(10,1.5,0)").text(), "null")
  assert_eq(@eval.feel_eval("date and time(2024,1.25,1,10,5,0)").text(), "null")
  assert_eq(@eval.feel_eval("date and time(2024,1,1,10.5,5,0)").text(), "null")
  assert_eq(@eval.feel_eval("date(2024,1,1)").text(), "2024-01-01")
  assert_eq(@eval.feel_eval("time(10,2,3.125)").text(), "10:02:03.125")
  assert_eq(
    @eval.feel_eval("date and time(2024,1,1,10,5,0.125)").text(),
    "2024-01-01T10:05:00.125",
  )
}
