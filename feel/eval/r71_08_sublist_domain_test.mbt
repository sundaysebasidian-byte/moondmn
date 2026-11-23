///|
test "Sublist enforces integer start and length within the selected tail" {
  assert_eq(@eval.feel_eval("sublist([1,2,3],0)=null").text(), "true")
  assert_eq(@eval.feel_eval("sublist([1,2,3],4)=null").text(), "true")
  assert_eq(@eval.feel_eval("sublist([1,2,3],-4)=null").text(), "true")
  assert_eq(@eval.feel_eval("sublist([1,2,3],2,3)=null").text(), "true")
  assert_eq(@eval.feel_eval("sublist([1,2,3],-2,3)=null").text(), "true")
  assert_eq(@eval.feel_eval("sublist([1,2,3],1.2)=null").text(), "true")
  assert_eq(@eval.feel_eval("sublist([1,2,3],1,1.5)=null").text(), "true")
  assert_eq(@eval.feel_eval("sublist([1,2,3],1,0)=null").text(), "true")
  assert_eq(@eval.feel_eval("sublist([1,2,3],2)=[2,3]").text(), "true")
  assert_eq(@eval.feel_eval("sublist([1,2,3],-3,3)=[1,2,3]").text(), "true")
  assert_eq(@eval.feel_eval("sublist([1,2,3],-1,1)=[3]").text(), "true")
}
