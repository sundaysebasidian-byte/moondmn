///|
test "unary wildcard comma range negation and implicit value" {
  let n = @types.Number(@types.decimal("3"))
  for s in ["-", "> 2", "[1..3]", "not(1,2)", "? > 1 and ? < 4"] {
    assert_true(@eval.unary_test(s, n, Map([])))
  }
  assert_false(@eval.unary_test("[1..3)", n, Map([])))
}
