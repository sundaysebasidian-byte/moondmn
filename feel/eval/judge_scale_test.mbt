///|
test "Scale domain is checked before fractional scale conversion" {
  assert_eq(@eval.feel_eval("decimal(1.5,6176.4)").text(), "null")
  assert_eq(@eval.feel_eval("round half up(1.35,-6111.3)").text(), "null")
  assert_eq(@eval.feel_eval("ceiling(1.4,6176.01)").text(), "null")
  assert_eq(@eval.feel_eval("floor(-1.21,1)").text(), "-1.3")
  assert_eq(@eval.feel_eval("decimal(1/3,2.5)").text(), "0.33")
  assert_eq(@eval.feel_eval("decimal(1.25,6176)").text(), "1.25")
  assert_eq(@eval.feel_eval("decimal(2.5,-6111)").text(), "0")
}
