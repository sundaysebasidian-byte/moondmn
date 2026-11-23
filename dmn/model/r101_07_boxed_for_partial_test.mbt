///|
test "Boxed for results expose an immutable prefix as partial" {
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><for iteratorVariable='x'><in><literalExpression ><text>[1,2,3,4]</text></literalExpression></in><return><literalExpression ><text>if count(partial) = 0 then x else partial[-1] + x</text></literalExpression></return></for></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[1, 3, 6, 10]",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><for iteratorVariable='x'><in><literalExpression ><text>[1,2,3,4]</text></literalExpression></in><return><literalExpression ><text>count(partial)</text></literalExpression></return></for></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[0, 1, 2, 3]",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><for iteratorVariable='x'><in><literalExpression ><text>[1,2,3,4]</text></literalExpression></in><return><literalExpression ><text>x + 1</text></literalExpression></return></for></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[2, 3, 4, 5]",
  )
}
