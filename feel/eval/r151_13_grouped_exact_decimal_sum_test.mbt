///|
test "Exact sum groups scales without changing cancellation or rounding" {
  assert_eq(@eval.feel_eval("sum([1e6000, 0.2, -1e6000, 0.3])").text(), "0.5")
  assert_eq(@eval.feel_eval("sum([1.1, 2.2, -1.1])").text(), "2.2")
  assert_eq(@eval.feel_eval("sum([1e-6176, 2e-6176]) = 3e-6176").text(), "true")
  assert_eq(
    @eval.feel_eval("sum([1e6000, -1e6000, 0, 0.01, -0.01])").text(),
    "0",
  )

  assert_eq(
    @eval.feel_eval(
      "mean([1e6000,1,-1e6000]) = 0.3333333333333333333333333333333333",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("mean([1e6000,-1e6000,1e-6100,-1e-6100])").text(),
    "0",
  )
}
