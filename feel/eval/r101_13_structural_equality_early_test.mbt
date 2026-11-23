///|
test "Structural equality still checks nested values and key sets" {
  assert_eq(@eval.feel_eval("[1,2,[3,4]] = [1,2,[3,4]]").text(), "true")
  assert_eq(@eval.feel_eval("[1,2,[3,5]] = [0,2,[3,4]]").text(), "false")
  assert_eq(@eval.feel_eval("[1,2,[3,5]] = [1,2,[3,4]]").text(), "false")
  assert_eq(@eval.feel_eval("{a:1,b:[2,3]} = {b:[2,3],a:1}").text(), "true")
  assert_eq(@eval.feel_eval("{a:1,b:[2,3]} = {c:1,b:[2,3]}").text(), "false")
  assert_eq(@eval.feel_eval("{a:1,b:[2,3]} = {a:1,b:[2,4]}").text(), "false")
}
