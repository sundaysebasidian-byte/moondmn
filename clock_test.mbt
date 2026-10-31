///|
test "fixed clock interpreted and compiled" {
  let instant = @types.parse_datetime("2024-02-29T23:30:00-05:00")
  let clock = Some(fn() { instant })
  inspect(
    @moondmn.feel_eval("now()", clock~),
    content="\"2024-02-29T23:30:00-05:00\"",
  )
  inspect(@moondmn.feel_eval("today()", clock~), content="\"2024-02-29\"")
  inspect(
    @moondmn.evaluate_compiled(@moondmn.compile("today()"), "{}", clock~),
    content="\"2024-02-29\"",
  )
}

///|
test "clock scopes do not leak" {
  let instant = @types.parse_datetime("2020-01-01T00:00:00Z")
  ignore(@moondmn.feel_eval("now()", clock=Some(fn() { instant })))
  let code = try {
    ignore(@moondmn.feel_eval("now()"))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_BUILTIN_UNSUPPORTED")
}

///|
test "clock reaches model literal expression" {
  let model = @moondmn.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><literalExpression><text>today()</text></literalExpression></decision></definitions>",
  )
  let instant = @types.parse_datetime("2024-02-29T00:00:00Z")
  inspect(
    @moondmn.evaluate_decision(model, "d", "{}", clock=Some(fn() { instant })),
    content="\"2024-02-29\"",
  )
}
