///|
test "Boxed filter lazily finds sibling fields without changing fallback or errors" {
  fn filtered(
    input : String,
    pred : String,
    ctx : Map[String, @types.Value],
  ) -> @types.Value raise @types.EngineError {
    let src = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><filter><in><literalExpression><text>" +
      input +
      "</text></literalExpression></in><match><literalExpression><text>" +
      pred +
      "</text></literalExpression></match></filter></decision></definitions>"
    @model.evaluate_decision(@model.parse_model(src), "d", ctx)
  }
  assert_eq(filtered("[{n:3},{n:7}]", "1", Map([])).text(), "{n: 3}")
  assert_eq(filtered("[{z:0},{n:7}]", "n &gt; 4", Map([])).text(), "[{n: 7}]")
  assert_eq(
    filtered(
      "[{z:0},{n:7}]",
      "n &gt; 4",
      Map([("n", @types.Number(@types.decimal_int(0)))]),
    ).text(),
    "[{n: 7}]",
  )
  let bad = try {
    ignore(filtered("[{z:0},{n:7}]", "typo &gt; 4", Map([])))
    false
  } catch {
    @types.Failure("E_NAME", _, _, _) => true
    e => raise e
  }
  assert_true(bad)
}
