///|
test "Named list replace distinguishes the position and match overloads" {
  assert_eq(
    @eval.feel_eval("list replace(list:[1,2],match:2,newItem:5)").text(),
    "null",
  )
  assert_eq(
    @eval.feel_eval(
      "list replace(position:function(i,n) true,list:[1,2],newItem:5)",
    ).text(),
    "null",
  )
  assert_eq(
    @eval.feel_eval(
      "list replace(list:[1,2],match:function(i,n) i < n,newItem:2)",
    ).text(),
    "[2, 2]",
  )
  assert_eq(
    @eval.feel_eval("list replace(list:[1,2],position:2,newItem:5)").text(),
    "[1, 5]",
  )
  assert_eq(@eval.feel_eval("list replace([1,2],2,5)").text(), "[1, 5]")
}
