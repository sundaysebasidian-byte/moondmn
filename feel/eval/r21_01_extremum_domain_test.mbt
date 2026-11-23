///|
test "Extrema require an orderable item even in a singleton list" {
  assert_eq(@eval.feel_eval("min([{a:1}])").text(), "null")
  assert_eq(@eval.feel_eval("max([{a:1}])").text(), "null")
  assert_eq(@eval.feel_eval("min([1..3])").text(), "null")
  assert_eq(@eval.feel_eval("min([7])").text(), "7")
  assert_eq(@eval.feel_eval("max([\"b\",\"a\"])").text(), "b")
}
