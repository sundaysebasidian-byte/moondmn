///|
test "Missing upper and lower range bounds are opposite infinities" {
  assert_eq(@eval.feel_eval("before((>3),0)").text(), "false")
  assert_eq(@eval.feel_eval("after(0,(>3))").text(), "false")
  assert_eq(@eval.feel_eval("before((>3),(<2))").text(), "false")
  assert_eq(@eval.feel_eval("meets((>3),(<2))").text(), "false")
  assert_eq(@eval.feel_eval("includes((>3),[4..5])").text(), "true")
  assert_eq(@eval.feel_eval("during(4,(>3))").text(), "true")
  assert_eq(@eval.feel_eval("includes((<3),-2)").text(), "true")
  assert_eq(@eval.feel_eval("starts([4..5],(>=4))").text(), "true")
  assert_eq(@eval.feel_eval("coincides((>3),(>3))").text(), "true")
  assert_eq(@eval.feel_eval("before((<2),(>3))").text(), "true")
  assert_eq(@eval.feel_eval("overlaps before([1..4],(>=3))").text(), "true")
  assert_eq(@eval.feel_eval("overlaps after((>=3),[1..4])").text(), "true")
  assert_eq(@eval.feel_eval("finishes((>=4),(>3))").text(), "true")
  assert_eq(@eval.feel_eval("before([1..2],[2..4])").text(), "false")
}
