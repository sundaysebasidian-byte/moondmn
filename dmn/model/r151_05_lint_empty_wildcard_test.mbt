///|
test "Lint recognizes blank wildcard cells only on complete rule rows" {
  assert_true(
    !@model.lint(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable><input><inputExpression><text>x</text></inputExpression></input><output/><rule><inputEntry><text>  </text></inputEntry><outputEntry><text>3</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
    )
    .stringify()
    .contains("W_POSSIBLE_GAP"),
  )
  assert_true(
    !@model.lint(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable><input><inputExpression><text>x</text></inputExpression></input><output/><rule><inputEntry><text>-</text></inputEntry><outputEntry><text>3</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
    )
    .stringify()
    .contains("W_POSSIBLE_GAP"),
  )
  assert_true(
    @model.lint(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable><input><inputExpression><text>x</text></inputExpression></input><output/><rule><outputEntry><text>3</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
    )
    .stringify()
    .contains("W_POSSIBLE_GAP"),
  )

  assert_true(
    @model.lint(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable><input><inputExpression><text>x</text></inputExpression></input><output/><rule><inputEntry><text>  </text></inputEntry></rule></decisionTable></decision></definitions>",
      ),
    )
    .stringify()
    .contains("W_POSSIBLE_GAP"),
  )
  assert_true(
    @model.lint(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable><input><inputExpression><text>x</text></inputExpression><inputValues><text>1,2</text></inputValues></input><output/><rule><inputEntry><text>  </text></inputEntry></rule></decisionTable></decision></definitions>",
      ),
    )
    .stringify()
    .contains("W_POSSIBLE_GAP"),
  )

  assert_true(
    @model.lint(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable><input><inputExpression><text>x</text></inputExpression></input><rule><inputEntry><text>  </text></inputEntry></rule></decisionTable></decision></definitions>",
      ),
    )
    .stringify()
    .contains("W_POSSIBLE_GAP"),
  )
}
