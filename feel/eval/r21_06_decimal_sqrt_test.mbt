///|
test "Square root preserves representable decimal128 magnitudes and precision" {
  assert_eq(@eval.feel_eval("sqrt(1e30) = 1e15").text(), "true")
  assert_eq(@eval.feel_eval("sqrt(1e-40) = 1e-20").text(), "true")
  assert_eq(@eval.feel_eval("sqrt(1e-6176) = 1e-3088").text(), "true")
  assert_eq(@eval.feel_eval("sqrt(1e6144) = 1e3072").text(), "true")
  assert_eq(
    @eval.feel_eval("sqrt(2) = 1.414213562373095048801688724209698").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("sqrt(0.09)").text(), "0.3")
  assert_eq(@eval.feel_eval("sqrt(0)").text(), "0")
  assert_eq(@eval.feel_eval("sqrt(-1)").text(), "null")
}
