///|
test "Sample deviation keeps an exact variance until rounding the root" {
  assert_eq(@eval.feel_eval("stddev([9e6144,9e6144]) = 0").text(), "true")
  assert_eq(
    @eval.feel_eval("stddev([1e4000,2e4000,3e4000]) = 1e4000").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("stddev([1e-4000,2e-4000,3e-4000]) = 1e-4000").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("stddev([1,2,3]) = 1").text(), "true")
  assert_eq(
    @eval.feel_eval("stddev([2,4,7,5]) = 2.081665999466132735282297706979931").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("stddev([8]) = null").text(), "true")
  assert_eq(@eval.feel_eval("stddev([1,null]) = null").text(), "true")
}
