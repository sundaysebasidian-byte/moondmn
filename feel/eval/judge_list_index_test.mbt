///|
test "List mutation positions never round a fractional index" {
  assert_eq(@eval.feel_eval("remove([10,20,30],1.6)").text(), "null")
  assert_eq(@eval.feel_eval("insert before([1,3],-1.4,2)").text(), "null")
  assert_eq(@eval.feel_eval("remove([10,20],-1)").text(), "[10]")
  assert_eq(@eval.feel_eval("insert before([1,3],2,2)").text(), "[1, 2, 3]")
  assert_eq(@eval.feel_eval("remove([1],0)").text(), "null")
}
