///|
test "Boxed contexts reject duplicate entry names" {
  let checked_same = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><context><contextEntry><variable name='x'/><literalExpression ><text>1</text></literalExpression></contextEntry><contextEntry><variable name='x'/><literalExpression ><text>2</text></literalExpression></contextEntry></context></decision></definitions>",
        ),
        "d",
        Map([]),
      ).text(),
    )
    false
  } catch {
    @types.Failure("E_DMN_CONTEXT", _, _, _) => true
    e => raise e
  }
  assert_true(checked_same)
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><context><contextEntry><variable name='x'/><literalExpression ><text>2</text></literalExpression></contextEntry><contextEntry><variable name='y'/><literalExpression ><text>x+1</text></literalExpression></contextEntry></context></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "{x: 2, y: 3}",
  )
}
