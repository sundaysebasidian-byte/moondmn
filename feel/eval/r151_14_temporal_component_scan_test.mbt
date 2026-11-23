///|
test "Time and date scan ASCII components with the same values and errors" {
  assert_eq(
    @eval.feel_eval(
      "time(\"10:02:03.123456789-00:03:04\").time offset = duration(\"-PT3M4S\")",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("time(\"12:05:00@America/New_York\").timezone").text(),
    "America/New_York",
  )
  assert_eq(@eval.feel_eval("time(\"12:05:00+02:0🚀\")").text(), "null")
  assert_eq(@eval.feel_eval("date(\"2024-02-29\").day").text(), "29")
  assert_eq(@eval.feel_eval("date(\"2023-02-29\")").text(), "null")

  let missing_digit = try {
    ignore(@types.parse_time("12:05:0Z"))
    false
  } catch {
    @types.Failure("E_PARSE", _, _, _) => true
    e => raise e
  }
  assert_true(missing_digit)
  let non_ascii_second = try {
    ignore(@types.parse_time("12:05:00+02:00:🚀"))
    false
  } catch {
    @types.Failure("E_PARSE", _, _, _) => true
    e => raise e
  }
  assert_true(non_ascii_second)
  let trailing = try {
    ignore(@types.parse_time("12:05:00Zextra"))
    false
  } catch {
    @types.Failure("E_TIME_INVALID", _, _, _) => true
    e => raise e
  }
  assert_true(trailing)
}
