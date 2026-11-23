///|
test "Lint never treats an unsupported unary test language as a FEEL catch-all" {
  let wrong = @model.lint(
    @model.parse_model(
      "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable ><input><inputExpression><text>x</text></inputExpression></input><output></output><rule><inputEntry expressionLanguage='urn:unsupported'><text>-</text></inputEntry><outputEntry><text>1</text></outputEntry></rule></decisionTable></decision></definitions>",
    ),
  ).stringify()
  assert_true(wrong.contains("E_LANGUAGE"))
  assert_true(wrong.contains("W_POSSIBLE_GAP"))
  let good = @model.lint(
    @model.parse_model(
      "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable ><input><inputExpression><text>x</text></inputExpression></input><output></output><rule><inputEntry ><text>-</text></inputEntry><outputEntry><text>1</text></outputEntry></rule></decisionTable></decision></definitions>",
    ),
  ).stringify()
  assert_true(!good.contains("E_LANGUAGE"))
  assert_true(!good.contains("W_POSSIBLE_GAP"))

  let bounded = @model.lint(
    @model.parse_model(
      "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable ><input><inputExpression><text>x</text></inputExpression><inputValues><text>1,2</text></inputValues></input><output></output><rule><inputEntry expressionLanguage='urn:unsupported'><text>-</text></inputEntry><outputEntry><text>1</text></outputEntry></rule></decisionTable></decision></definitions>",
    ),
  ).stringify()
  assert_true(
    bounded.contains("E_LANGUAGE") && bounded.contains("W_POSSIBLE_GAP"),
  )
}
