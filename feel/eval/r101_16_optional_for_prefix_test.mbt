///|
test "Partial snapshots remain immutable when referenced by loops" {
  assert_eq(
    @eval.feel_eval("for i in 1..5 return i * 2").text(),
    "[2, 4, 6, 8, 10]",
  )
  assert_eq(
    @eval.feel_eval("for i in 1..4 return if i = 1 then 1 else i * partial[-1]").text(),
    "[1, 2, 6, 24]",
  )
  assert_eq(
    @eval.feel_eval("for i in 1..4 return count(partial)").text(),
    "[0, 1, 2, 3]",
  )
}
