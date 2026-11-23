///|
test "Calendar duration years and months cannot be fractional" {
  assert_eq(@eval.feel_eval("duration(\"P1.5Y\")").text(), "null")
  assert_eq(@eval.feel_eval("duration(\"P2.25M\")").text(), "null")
  assert_eq(@eval.feel_eval("duration(\"P1Y0.5M\")").text(), "null")
  assert_eq(
    @eval.feel_eval("duration(\"P1.00000000000000000000000000000000000001Y\")").text(),
    "null",
  )
  assert_eq(@eval.feel_eval("duration(\"P2.0M\")").text(), "null")
  assert_eq(@eval.feel_eval("duration(\"P1Y2,0M\")").text(), "null")
  assert_eq(
    @eval.feel_eval("duration(\"P1Y2M\") = duration(\"P14M\")").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("duration(\"PT1.5M\") = duration(\"PT90S\")").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("duration(\"P2DT0.25S\") = duration(\"PT48H0.25S\")").text(),
    "true",
  )
}
