///|
test "Literal intervals enforce ordered compatible endpoints like range text" {
  assert_eq(@eval.feel_eval("[3..1]").text(), "null")
  assert_eq(@eval.feel_eval("[1..\"z\"]").text(), "null")
  assert_eq(@eval.feel_eval("[null..3]").text(), "null")
  assert_eq(@eval.feel_eval("[3..3].start").text(), "3")
  assert_eq(@eval.feel_eval("range(\"[3..1]\")").text(), "null")
  assert_eq(@eval.feel_eval("2 in (1..4]").text(), "true")
  assert_eq(@eval.feel_eval("for n in 3..1 return n").text(), "[3, 2, 1]")
}
