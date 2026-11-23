///|
test "insert before supports positions counted from the end" {
  inspect(
    @eval.feel_eval("insert before([1,3], -1, 2)").json().stringify(),
    content="[1,2,3]",
  )
  inspect(
    @eval.feel_eval("insert before([1,3], -2, null)").json().stringify(),
    content="[null,1,3]",
  )
  inspect(
    @eval.feel_eval("insert before([1,3], 3, 2)").json().stringify(),
    content="[1,3,2]",
  )
}
