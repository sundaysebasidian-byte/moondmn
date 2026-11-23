///|
test "DMN literals inherit their model language and honor explicit FEEL overrides" {
  let checked_inherited = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' expressionLanguage='https://example.org/NOTFEEL/'><decision id='d' name='d'><literalExpression ><text>1 + 1</text></literalExpression></decision></definitions>",
        ),
        "d",
        Map([]),
      ).text(),
    )
    false
  } catch {
    @types.Failure("E_LANGUAGE", _, _, _) => true
    e => raise e
  }
  assert_true(checked_inherited)
  let checked_fake = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><literalExpression expressionLanguage='https://example.org/NOTFEEL/'><text>1 + 1</text></literalExpression></decision></definitions>",
        ),
        "d",
        Map([]),
      ).text(),
    )
    false
  } catch {
    @types.Failure("E_LANGUAGE", _, _, _) => true
    e => raise e
  }
  assert_true(checked_fake)
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' expressionLanguage='https://example.org/NOTFEEL/'><decision id='d' name='d'><literalExpression expressionLanguage='https://www.omg.org/spec/DMN/20230324/FEEL/'><text>1 + 1</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "2",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' expressionLanguage='https://www.omg.org/spec/DMN/20230324/FEEL/'><decision id='d' name='d'><literalExpression ><text>1 + 1</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "2",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><literalExpression expressionLanguage='FEEL'><text>1 + 1</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "2",
  )
  let checked_table = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' ><decision id='d' name='d'><decisionTable><output/><rule><outputEntry expressionLanguage='https://example.org/NOTFEEL/'><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
        ),
        "d",
        Map([]),
      ).text(),
    )
    false
  } catch {
    @types.Failure("E_LANGUAGE", _, _, _) => true
    e => raise e
  }
  assert_true(checked_table)
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101' expressionLanguage='https://example.org/NOTFEEL/'><decision id='d' name='d'><decisionTable><output/><rule><outputEntry expressionLanguage='https://www.omg.org/spec/DMN/20230324/FEEL/'><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "2",
  )
}
