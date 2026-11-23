///|
test "Mean rounds only after dividing the exact sum" {
  assert_eq(@eval.feel_eval("mean([9e6144,9e6144]) = 9e6144").text(), "true")
  assert_eq(@eval.feel_eval("mean([1e34,1,-1e34]) = 1/3").text(), "true")
  assert_eq(@eval.feel_eval("mean([-1e34,1,1e34]) = 1/3").text(), "true")
  assert_eq(@eval.feel_eval("mean(1e-6176,2e-6176) = 2e-6176").text(), "true")
  assert_eq(@eval.feel_eval("mean(4,8,9)").text(), "7")
  assert_eq(@eval.feel_eval("mean([])").text(), "null")
  assert_eq(@eval.feel_eval("mean(1,null)").text(), "null")
  assert_eq(@eval.feel_eval("mean(2,\"x\")").text(), "null")
}
