///|
test "Exponentials retain significance when the answer does not fit a scaled Int64" {
  assert_eq(@eval.feel_eval("exp(30) > 10686474581523 and exp(30) < 10686474581526").text(), "true")
  assert_eq(@eval.feel_eval("exp(-30) > 9.3576e-14 and exp(-30) < 9.3577e-14").text(), "true")
  assert_eq(@eval.feel_eval("exp(1000) > 1.9700e434 and exp(1000) < 1.9701e434").text(), "true")
  assert_eq(@eval.feel_eval("exp(-20000)").text(), "0")
  assert_eq(@eval.feel_eval("exp(0)").text(), "1")
  assert_eq(@eval.feel_eval("exp(1e6000)").text(), "null")
}
