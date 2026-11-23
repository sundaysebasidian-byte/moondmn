///|
test "FEEL parses multiple parameters in function type descriptors" {
  assert_eq(
    @eval.feel_eval(
      "(function(x,y) x+y) instance of function<number,number> -> number",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("1 instance of function<number,number> -> number").text(),
    "false",
  )
  assert_eq(
    @eval.feel_eval("(function(x) x) instance of function<number> -> number").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("(function() 1) instance of function<> -> number").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "(function(x) x) instance of function<number,number> -> number",
    ).text(),
    "false",
  )
  assert_eq(
    @eval.feel_eval(
      "(function(x,y,z) x+y+z) instance of function<number,number> -> number",
    ).text(),
    "false",
  )
  assert_eq(
    @eval.feel_eval(
      "(function(row,rate) rate) instance of function<context<price:number,label:string>,number> -> number",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "(function(row) row) instance of function<context<price:number,label:string>,number> -> number",
    ).text(),
    "false",
  )
  assert_eq(
    @eval.feel_eval(
      "(function(f,x) x) instance of function<function<number,number> -> number,number> -> number",
    ).text(),
    "true",
  )
}
