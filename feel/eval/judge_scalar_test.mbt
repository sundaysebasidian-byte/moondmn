///|
test "A builtin scalar formal unwraps only a single compatible item" {
  assert_eq(@eval.feel_eval("sqrt([9])").text(), "3")
  assert_eq(@eval.feel_eval("contains([[\"abc\"]],\"a\")").text(), "null")
  assert_eq(@eval.feel_eval("string length([\"😀ab\"])").text(), "3")
  assert_eq(@eval.feel_eval("abs([[1]])").text(), "null")
  assert_eq(@eval.feel_eval("modulo([7],[3])").text(), "1")
  assert_eq(@eval.feel_eval("sum([[1],[2]])").text(), "null")
  assert_eq(@eval.feel_eval("sqrt([1,2])").text(), "null")
  assert_eq(@eval.feel_eval("string join([[\"a\"]],\",\")").text(), "null")
}
