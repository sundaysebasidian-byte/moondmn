///|
test "A missing field in one boxed filter item does not discard valid matches" {
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><filter><in><literalExpression ><text>[{description:\"x\"}, {price:8}, {price:2}]</text></literalExpression></in><match><literalExpression ><text>price &gt; 5</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[{price: 8}]",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><filter><in><literalExpression ><text>[{price:8}, {description:\"x\"}, {price:2}]</text></literalExpression></in><match><literalExpression ><text>price &gt; 5</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[{price: 8}]",
  )
  let typo = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><filter><in><literalExpression ><text>[{description:\"x\"}]</text></literalExpression></in><match><literalExpression ><text>price &gt; 5</text></literalExpression></match></filter></decision></definitions>",
        ),
        "d",
        Map([]),
      ).text(),
    )
    false
  } catch {
    @types.Failure("E_NAME", _, _, _) => true
    e => raise e
  }
  assert_true(typo)
  let complex_missing = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><filter><in><literalExpression ><text>[{description:\"x\"}, {price:8}, {price:2}]</text></literalExpression></in><match><literalExpression ><text>if true then price &gt; 5 else false</text></literalExpression></match></filter></decision></definitions>",
        ),
        "d",
        Map([]),
      ).text(),
    )
    false
  } catch {
    @types.Failure("E_NAME", _, _, _) => true
    e => raise e
  }
  assert_true(complex_missing)
  let malformed = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><filter><in><literalExpression ><text>[{description:\"x\"}, {price:8}, {price:2}]</text></literalExpression></in><match><literalExpression ><text>price &gt; )</text></literalExpression></match></filter></decision></definitions>",
        ),
        "d",
        Map([]),
      ).text(),
    )
    false
  } catch {
    @types.Failure("E_PARSE", _, _, _) => true
    e => raise e
  }
  assert_true(malformed)
}
