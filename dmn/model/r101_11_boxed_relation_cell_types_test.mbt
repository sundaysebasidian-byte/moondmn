///|
test "Relation cells honor their declared column type" {
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><relation><column name='x' typeRef='number'/><row><literalExpression ><text>\"not a number\"</text></literalExpression></row></relation></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "null",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><relation><column name='x' typeRef='number'/><row><literalExpression ><text>8</text></literalExpression></row></relation></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[{x: 8}]",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><relation><column name='x' typeRef='Any'/><row><literalExpression ><text>\"word\"</text></literalExpression></row></relation></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[{x: word}]",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' xmlns:f='https://www.omg.org/spec/DMN/20230324/FEEL/' ><decision id='d' name='d'><relation><column name='x' typeRef='f:number'/><row><literalExpression ><text>8</text></literalExpression></row></relation></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[{x: 8}]",
  )
}
