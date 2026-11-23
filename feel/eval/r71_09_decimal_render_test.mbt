///|
test "Decimal text stays identical across fixed-point placement and large scales" {
  assert_eq(@eval.feel_eval("string(0) = \"0\"").text(), "true")
  assert_eq(@eval.feel_eval("string(123.456) = \"123.456\"").text(), "true")
  assert_eq(@eval.feel_eval("string(-123.456) = \"-123.456\"").text(), "true")
  assert_eq(@eval.feel_eval("string(0.3) = \"0.3\"").text(), "true")
  assert_eq(@eval.feel_eval("string(-0.3) = \"-0.3\"").text(), "true")
  assert_eq(
    @eval.feel_eval("string(-0.0000000032) = \"-0.0000000032\"").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("string(-1200000000) = \"-1200000000\"").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("string length(string(1e-6176)) = 6178").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("string length(string(9e6144)) = 6145").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("number(string(-1e-6176)) = -1e-6176").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("number(string(9e6144)) = 9e6144").text(), "true")
}
