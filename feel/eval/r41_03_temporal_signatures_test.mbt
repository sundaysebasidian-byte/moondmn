///|
test "Temporal named arguments cannot combine overloads or repeat names" {
  assert_eq(
    @eval.feel_eval("date(from:\"2024-01-01\",year:2025)").text(),
    "null",
  )
  assert_eq(
    @eval.feel_eval("date(from:\"2024-01-01\",from:\"2024-01-02\")").text(),
    "null",
  )
  assert_eq(
    @eval.feel_eval(
      "date and time(date:date(\"2024-01-01\"),time:time(\"12:00:00\"),year:2026)",
    ).text(),
    "null",
  )
  assert_eq(
    @eval.feel_eval("date and time(time:time(\"12:00:00\"))").text(),
    "null",
  )
  assert_eq(
    @eval.feel_eval("date and time(date:date(\"2024-01-01\"))").text(),
    "null",
  )
  assert_eq(
    @eval.feel_eval("date(from:\"2024-01-01\") = date(year:2024,month:1,day:1)").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "date and time(time:time(\"12:00:00\"),date:date(\"2024-01-01\")) = @\"2024-01-01T12:00:00\"",
    ).text(),
    "true",
  )
}
