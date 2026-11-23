///|
test "Quantization requires an integral scale" {
  assert_eq(@eval.feel_eval("decimal(1.234,1.6)").text(), "null")
  assert_eq(@eval.feel_eval("round half up(1.35,-0.2)").text(), "null")
  assert_eq(@eval.feel_eval("ceiling(1.4,0.3)").text(), "null")
  assert_eq(@eval.feel_eval("floor(-1.21,1)").text(), "-1.3")
  assert_eq(@eval.feel_eval("decimal(2.5,0)").text(), "2")
  assert_eq(@eval.feel_eval("decimal(2.5,6177)").text(), "null")
}
