///|
test "Sort validates declared comparator arity without rejecting optional builtins" {
  assert_eq(@eval.feel_eval("sort([],function(x) true)").text(), "null")
  assert_eq(@eval.feel_eval("sort([1],function(x,y,z) true)").text(), "null")
  assert_eq(@eval.feel_eval("sort([1],function(x:number) true)").text(), "null")
  assert_eq(@eval.feel_eval("sort([],function(x,y) x<y)").text(), "[]")
  assert_eq(@eval.feel_eval("sort([2,1],function(x,y) x<y)").text(), "[1, 2]")
  assert_eq(
    @eval.feel_eval("sort([\"a\",\"b\"],matches) = [\"a\",\"b\"]").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("sort([],matches)").text(), "[]")
  assert_eq(
    @eval.feel_eval("sort([false,true],any) = [true,false]").text(),
    "true",
  )
}
