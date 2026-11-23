///|
test "Numeric fixed offset seconds survive time and date-time text round trips" {
  assert_eq(
    @eval.feel_eval(
      "time(string(time(10,20,30,duration(\"PT32S\")))) = time(10,20,30,duration(\"PT32S\"))",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "date and time(string(date and time(date(\"2024-04-11\"),time(10,20,30,duration(\"-PT32S\"))))) = date and time(date(\"2024-04-11\"),time(10,20,30,duration(\"-PT32S\")))",
    ).text(),
    "true",
  )
  assert_eq(@eval.feel_eval("time(\"10:20:30+14:00:01\")").text(), "null")
  assert_eq(@eval.feel_eval("time(\"10:20:30+00:00:60\")").text(), "null")
  assert_eq(@eval.feel_eval("time(\"10:20:30+00:00:3\")").text(), "null")
  assert_eq(
    @eval.feel_eval("time(\"10:20:30+00:00\") = time(\"10:20:30Z\")").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "time(\"10:20:30-14:00:00\").time offset = duration(\"-PT14H\")",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "time(\"10:20:30+13:59:59\") = time(string(time(10,20,30,duration(\"PT13H59M59S\"))))",
    ).text(),
    "true",
  )
  assert_eq(@eval.feel_eval("time(\"10:20:30-14:00:01\")").text(), "null")
  assert_eq(@eval.feel_eval("time(\"12:05:00+02:00:🚀\")").text(), "null")
}
