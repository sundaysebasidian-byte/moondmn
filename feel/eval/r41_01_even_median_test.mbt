///|
test "Even median averages only its central pair with one rounding" {
  assert_eq(@eval.feel_eval("median([9e6144,9e6144]) = 9e6144").text(), "true")
  assert_eq(
    @eval.feel_eval("median([-9e6144,-9e6144]) = -9e6144").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "median([1.000000000000000000000000000000002,1.000000000000000000000000000000003]) = 1.000000000000000000000000000000002",
    ).text(),
    "true",
  )
  assert_eq(@eval.feel_eval("median([1,4,8]) = 4").text(), "true")
  assert_eq(@eval.feel_eval("median([1,3,7,9]) = 5").text(), "true")
}
