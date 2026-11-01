///|
test "arithmetic, scoped names, records and short circuit" {
  inspect(@eval.feel_eval("0.1 + 0.2 * 3").json().stringify(), content="0.7")
  let ctx = @types.json_context("{\"Applicant Age\":22,\"a-b\":3}")
  inspect(
    @eval.feel_eval("if Applicant Age >= 18 then a-b else 0", ctx~)
    .json()
    .stringify(),
    content="3",
  )
  inspect(
    @eval.feel_eval("false and missing").json().stringify(),
    content="false",
  )
  inspect(@eval.feel_eval("{a: 2, b: a + 1}.b").json().stringify(), content="3")
}

///|
test "null differs from runtime failure" {
  inspect(@eval.feel_eval("null + 1").json().stringify(), content="null")
  inspect(@eval.feel_eval("1 / 0").json().stringify(), content="null")
  assert_true(
    try {
      ignore(@eval.feel_eval("1 +\n )"))
      false
    } catch {
      @types.Failure(_, l, c, _) => l == 2 && c == 2
    },
  )
}

///|
test "typed function invocation implicit conversions" {
  for
    (source, expected) in [
      ("(function(x:list<number>) x)(1)", "[1]"),
      ("(function(x:list<number>) x)([1,2])", "[1,2]"),
      ("(function(x:list<number>) x)([1])", "[1]"),
      ("(function(x:list<number>) x)([])", "[]"),
      ("(function(x:list<list<number>>) x)([1,2])", "[[1,2]]"),
      ("(function(x:list<number>) 1)(null)", "1"),
      ("(function(x:list<number>) x)(true)", "null"),
      ("(function(x:list<number>) x)([1,true])", "null"),
      ("(function(x:number) x)([1])", "1"),
      ("(function(x:number) x)([true])", "null"),
      (
        "(function(x:date and time) x)(date(\"2020-01-01\"))", "\"2020-01-01T00:00:00Z\"",
      ),
      (
        "(function(x:date and time) x)([date(\"2020-01-01\")])", "\"2020-01-01T00:00:00Z\"",
      ),
      (
        "(function(x:date and time) x)(date and time(\"2020-01-01T12:30:00+02:00\"))",
        "\"2020-01-01T12:30:00+02:00\"",
      ),
      ("(function(x:date and time) x)([1])", "null"),
    ] {
    assert_eq(@eval.feel_eval(source).json().stringify(), expected)
  }
}
