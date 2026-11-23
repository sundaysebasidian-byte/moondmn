///|
test "Boxed lists ignore DMN description and extension metadata" {
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><list><description>Line items</description><extensionElements><f:meta xmlns:f='urn:supplement'>42</f:meta></extensionElements><literalExpression ><text>1</text></literalExpression><literalExpression ><text>2</text></literalExpression></list></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[1, 2]",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><list><description>No entries</description></list></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[]",
  )
  let unknown_still_invalid = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><list><mystery/></list></decision></definitions>",
        ),
        "d",
        Map([]),
      ).text(),
    )
    false
  } catch {
    @types.Failure("E_DMN_UNSUPPORTED", _, _, _) => true
    e => raise e
  }
  assert_true(unknown_still_invalid)
}
