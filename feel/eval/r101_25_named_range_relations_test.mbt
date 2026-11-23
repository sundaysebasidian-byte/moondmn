///|
test "FEEL range relations bind documented named range endpoints" {
  assert_eq(
    @eval.feel_eval("overlaps(range1:[1..4],range2:[3..5])").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("overlaps before(range2:[4..8],range1:[1..5])").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("before(range1:[1..2],range2:[3..4])").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("before(point1:1,point2:2)").text(), "true")
  assert_eq(
    @eval.feel_eval("includes(range1:[1..9],range2:[2..5])").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("overlaps(range1:1,range2:[3..5])").text(), "null")
  assert_eq(
    @eval.feel_eval("overlaps(range1:[1..2],point1:[1..2],range2:[3..5])").text(),
    "null",
  )
  assert_eq(@eval.feel_eval("sum(range1:[1..4])").text(), "null")
}
