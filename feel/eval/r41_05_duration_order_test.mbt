///|
test "Duration components are ordered, single-use and have at most one time separator" {
  assert_eq(@eval.feel_eval("duration(\"PT2M1H\")").text(), "null")
  assert_eq(@eval.feel_eval("duration(\"P2D3D\")").text(), "null")
  assert_eq(@eval.feel_eval("duration(\"PTT2H\")").text(), "null")
  assert_eq(@eval.feel_eval("duration(\"P1M2Y\")").text(), "null")
  assert_eq(
    @eval.feel_eval("duration(\"P1DT2H3M4.5S\") = duration(\"PT26H3M4.5S\")").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("duration(\"P1Y2M\") = duration(\"P14M\")").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("duration(\"P2W\") = duration(\"P14D\")").text(),
    "true",
  )
}
