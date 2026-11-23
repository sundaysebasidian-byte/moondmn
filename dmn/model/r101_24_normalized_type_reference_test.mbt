///|
test "FEEL type references accept XML's surrounding whitespace" {
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><variable typeRef='  number  '/><literalExpression ><text>2</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "2",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><literalExpression typeRef=' number '><text>2</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "2",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><variable typeRef='  number  '/><literalExpression ><text>\"bad\"</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "null",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><variable typeRef='number'/><literalExpression ><text>1</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "1",
  )
}
