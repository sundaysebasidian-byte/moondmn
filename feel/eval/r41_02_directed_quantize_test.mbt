///|
test "Scaled directed rounding uses integer digits without an intermediate decimal factor" {
  assert_eq(@eval.feel_eval("floor(9e6144,2) = 9e6144").text(), "true")
  assert_eq(@eval.feel_eval("ceiling(-9e6144,3) = -9e6144").text(), "true")
  assert_eq(@eval.feel_eval("round up(1e-6176,6175) = 1e-6175").text(), "true")
  assert_eq(
    @eval.feel_eval("round half up(-5e-6176,6175) = -1e-6175").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("round half down(5e-6176,6175) = 0").text(), "true")
  assert_eq(@eval.feel_eval("round down(-123,-1) = -120").text(), "true")
  assert_eq(@eval.feel_eval("floor(-0.1) = -1").text(), "true")
  assert_eq(@eval.feel_eval("ceiling(0.1) = 1").text(), "true")
  assert_eq(@eval.feel_eval("floor(1,null) = null").text(), "true")
}
