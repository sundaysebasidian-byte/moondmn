///|
test "Natural logarithm handles the full decimal exponent range" {
  assert_eq(@eval.feel_eval("log(1e400) = 921.03403720").text(), "true")
  assert_eq(@eval.feel_eval("log(1e-400) = -921.03403720").text(), "true")
  assert_eq(@eval.feel_eval("log(1e-6176) = -14220.76553433").text(), "true")
  assert_eq(@eval.feel_eval("log(9e6144) = 14149.28003593").text(), "true")
  assert_eq(@eval.feel_eval("log(1) = 0").text(), "true")
  assert_eq(@eval.feel_eval("log(10) = 2.30258509").text(), "true")
  assert_eq(
    @eval.feel_eval("log(1.000000005000000013500000025833333) = 0.00000001").text(),
    "true",
  )
}
