///|
test "Standard formal parameter spelling binds without leaking overload aliases" {
  assert_eq(@eval.feel_eval("index of(match:2,list:[1,2,2])").text(), "[2, 3]")
  assert_eq(@eval.feel_eval("not(negand:false)").text(), "true")
  assert_eq(@eval.feel_eval("get value(m:{x:1},keys:\"x\")").text(), "null")
  assert_eq(@eval.feel_eval("not(true)").text(), "false")
  assert_eq(@eval.feel_eval("list contains(list:[2],element:2)").text(), "true")
  assert_eq(@eval.feel_eval("index of(list:[2],unknown:2)").text(), "null")
}
