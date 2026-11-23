///|
test "Boxed relations reject duplicate columns instead of overwriting cells" {
  let checked_same = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><relation><column name='x' typeRef='number'/><column name='x' typeRef='number'/><row><literalExpression ><text>1</text></literalExpression><literalExpression ><text>2</text></literalExpression></row></relation></decision></definitions>",
        ),
        "d",
        Map([]),
      ).text(),
    )
    false
  } catch {
    @types.Failure("E_DMN_RELATION", _, _, _) => true
    e => raise e
  }
  assert_true(checked_same)
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><relation><column name='x' typeRef='number'/><column name='y' typeRef='number'/><row><literalExpression ><text>2</text></literalExpression><literalExpression ><text>3</text></literalExpression></row></relation></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[{x: 2, y: 3}]",
  )
}
