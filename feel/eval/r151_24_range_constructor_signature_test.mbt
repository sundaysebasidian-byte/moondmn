///|
test "Existing temporal range constructors honor call spacing and argument names" {
  assert_eq(
    @eval.feel_eval(
      "range(\"[date (\\\"2024-01-01\\\")..date (from:\\\"2024-01-03\\\")]\").end",
    ).text(),
    "2024-01-03",
  )
  assert_eq(
    @eval.feel_eval(
      "range(\"[date(other:\\\"2024-01-01\\\")..date(\\\"2024-01-03\\\")]\")",
    ).text(),
    "null",
  )
  assert_eq(
    @eval.feel_eval(
      "range(\"[date(\\\"2024-01-01\\\")..date(\\\"2024-01-03\\\")]\").start",
    ).text(),
    "2024-01-01",
  )
}
