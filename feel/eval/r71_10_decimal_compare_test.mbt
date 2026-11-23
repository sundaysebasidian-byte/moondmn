///|
test "Decimal comparisons preserve order across equal scales signs and extremes" {
  assert_eq(@eval.feel_eval("1.2345 < 1.9876").text(), "true")
  assert_eq(@eval.feel_eval("-1.9876 < -1.2345").text(), "true")
  assert_eq(@eval.feel_eval("1.50 = 1.5").text(), "true")
  assert_eq(@eval.feel_eval("50.0 = 5e1").text(), "true")
  assert_eq(@eval.feel_eval("-0.001 < 0").text(), "true")
  assert_eq(@eval.feel_eval("0 < 1e-6176").text(), "true")
  assert_eq(@eval.feel_eval("1e-6176 < 9e6144").text(), "true")
  assert_eq(@eval.feel_eval("-9e6144 < -1e-6176").text(), "true")
  assert_eq(@eval.feel_eval("-9e6144 < 1e-6176").text(), "true")
  assert_eq(@eval.feel_eval("(0 = -0) and (1.0001 > 1)").text(), "true")
  assert_eq(@eval.feel_eval("9e6144 = 9e6144").text(), "true")
}
