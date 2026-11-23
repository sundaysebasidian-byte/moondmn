///|
test "An empty grouping separator is not a synonym for a null separator" {
  assert_eq(@eval.feel_eval("number(\"123\",\"\",null)").text(), "null")
  assert_eq(@eval.feel_eval("number(\"1.2\",\"\",\".\")").text(), "null")
  assert_eq(@eval.feel_eval("number(\"123\",null,null)").text(), "123")
  assert_eq(
    @eval.feel_eval("number(\"1 234,50\",\" \",\",\")").text(),
    "1234.5",
  )
  assert_eq(@eval.feel_eval("number(\"123\")").text(), "123")
  assert_eq(@eval.feel_eval("number(\"1\",\"x\",null)").text(), "null")
}
