///|
test "Sum preserves cancelling terms and rounds only the final result" {
  assert_eq(@eval.feel_eval("sum(1e34,1,-1e34) = 1").text(), "true")
  assert_eq(@eval.feel_eval("sum([-1e34,1,1e34]) = 1").text(), "true")
  assert_eq(
    @eval.feel_eval("sum([9e6144,9e6144,-9e6144]) = 9e6144").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("sum([1e-6176,-1e-6176]) = 0").text(), "true")
  assert_eq(@eval.feel_eval("sum(1.25,-0.5,3) = 3.75").text(), "true")
  assert_eq(@eval.feel_eval("sum([]) = null").text(), "true")
  assert_eq(@eval.feel_eval("sum(1,null) = null").text(), "true")
}
