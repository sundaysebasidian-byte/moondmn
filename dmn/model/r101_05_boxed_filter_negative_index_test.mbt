///|
test "Boxed numeric filters honor one-based reverse positions" {
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><filter><in><literalExpression><text>[2, 4, 6]</text></literalExpression></in><match><literalExpression><text>-1</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "6",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><filter><in><literalExpression><text>[2, 4, 6]</text></literalExpression></in><match><literalExpression><text>-3</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "2",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><filter><in><literalExpression><text>[2, 4, 6]</text></literalExpression></in><match><literalExpression><text>-4</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "null",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><filter><in><literalExpression><text>[2, 4, 6]</text></literalExpression></in><match><literalExpression><text>0</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "null",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><filter><in><literalExpression><text>[2, 4, 6]</text></literalExpression></in><match><literalExpression><text>2</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "4",
  )
}
