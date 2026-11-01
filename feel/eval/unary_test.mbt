///|
test "unary wildcard comma range negation and implicit value" {
  let n = @types.Number(@types.decimal("3"))
  for s in ["-", "> 2", "[1..3]", "not(1,2)", "? > 1 and ? < 4"] {
    assert_true(@eval.unary_test(s, n, Map([])))
  }
  assert_false(@eval.unary_test("[1..3)", n, Map([])))
}

///|
test "boolean unary expressions use input references to select predicates" {
  for
    (source, expected) in [
      ("false in (1=2)", "true"),
      ("true in (1=1)", "true"),
      ("false in (1=1)", "false"),
      ("true in (1=2)", "false"),
      ("false in (not(true))", "true"),
      ("false in ((function() false)())", "true"),
      ("false in (if true then false else true)", "true"),
      ("false in (string length(\"?\") = 0)", "true"),
      ("3 in (? > 1 and ? < 4)", "true"),
      ("3 in (? < 1)", "false"),
      ("3 in ((function(x) x > 1)(?))", "true"),
      ("3 in ({ok: ? > 1}.ok)", "true"),
      ("3 in (if ? > 1 then true else false)", "true"),
      ("3 in (? in (> 1))", "true"),
    ] {
    assert_eq(@eval.feel_eval(source).json().stringify(), expected)
  }
}
