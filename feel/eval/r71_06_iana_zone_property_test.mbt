///|
test "The timezone property returns only an IANA identifier" {
  assert_eq(
    @eval.feel_eval("time(\"11:22:33+02:30\").timezone = null").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("time(\"11:22:33Z\").timezone = null").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "date and time(\"2022-05-03T11:22:33-03:30\").timezone = null",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("time(\"11:22:33\").timezone = null").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "time(\"11:22:33@Europe/Paris\").timezone = \"Europe/Paris\"",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "date and time(\"2022-05-03T11:22:33@Europe/Paris\").timezone = \"Europe/Paris\"",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "time(\"11:22:33+02:30\").time offset = duration(\"PT2H30M\")",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("time(\"11:22:33Z\").time offset = duration(\"PT0S\")").text(),
    "true",
  )
}
