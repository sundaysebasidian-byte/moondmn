///|
test "Date and time component overload honors its offset" {
  assert_eq(
    @eval.feel_eval(
      "date and time(2024,1,1,12,30,0,duration(\"PT1H\")).time offset = duration(\"PT1H\")",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "date and time(2024,1,1,12,30,0,\"-03:30\") = @\"2024-01-01T16:00:00Z\"",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("date and time(2024,1,1,12,30,0,99)").text(),
    "null",
  )
  assert_eq(
    @eval.feel_eval("date and time(2024,1,1) = @\"2024-01-01T00:00:00\"").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "date and time(2024,1,1,5,6,7.125) = @\"2024-01-01T05:06:07.125\"",
    ).text(),
    "true",
  )
}
