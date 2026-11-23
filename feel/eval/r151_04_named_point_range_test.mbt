///|
test "Unambiguous FEEL point-range overloads accept their standard named parameters" {
  assert_eq(@eval.feel_eval("includes(point:3,range:[1..4])").text(), "true")
  assert_eq(@eval.feel_eval("during(range:[1..4],point:3)").text(), "true")
  assert_eq(@eval.feel_eval("starts(range:[1..4],point:1)").text(), "true")
  assert_eq(@eval.feel_eval("finished by(point:4,range:[1..4])").text(), "true")
  assert_eq(@eval.feel_eval("finishes(point:4,range:[1..4))").text(), "false")
  assert_eq(@eval.feel_eval("started by(range:(1..4],point:1)").text(), "false")
  assert_eq(@eval.feel_eval("includes(range:1,point:1)").text(), "null")
  assert_eq(
    @eval.feel_eval("includes(point:[1..2],range:[1..4])").text(),
    "null",
  )
  assert_eq(@eval.feel_eval("before(point:0,range:[1..4])").text(), "null")
  assert_eq(
    @eval.feel_eval("includes(range1:[1..4],range2:[2..3])").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("includes(range:[1..4],range2:[2..3])").text(),
    "null",
  )
  assert_eq(@eval.feel_eval("includes(point1:[1..4],point:2)").text(), "null")
  assert_eq(
    @eval.feel_eval(
      "during(range:[date(\"2024-01-01\")..date(\"2024-12-31\")],point:date(\"2024-03-01\"))",
    ).text(),
    "true",
  )
}
