///|
fn model(policy : String) -> @model.Model raise @types.EngineError {
  @model.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='" +
    policy +
    "'><input><inputExpression><text>n</text></inputExpression></input><output name='result'/><rule><inputEntry><text>&gt; 0</text></inputEntry><outputEntry><text>1</text></outputEntry></rule><rule><inputEntry><text>&gt; 0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
  )
}

///|
test "table hit policies and lint warnings" {
  let ctx = @types.json_context("{\"n\":3}")
  assert_true(
    try {
      ignore(@model.evaluate_decision(model("UNIQUE"), "d", ctx))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@model.evaluate_decision(model("ANY"), "d", ctx))
      false
    } catch {
      _ => true
    },
  )
  inspect(
    @model.evaluate_decision(model("FIRST"), "d", ctx).json().stringify(),
    content="1",
  )
  inspect(
    @model.evaluate_decision(model("RULE ORDER"), "d", ctx).json().stringify(),
    content="[1,2]",
  )
  inspect(
    @model.evaluate_decision(model("COLLECT"), "d", ctx).json().stringify(),
    content="[1,2]",
  )
  assert_true(
    @model.lint(model("UNIQUE"))
    .stringify()
    .contains("W_IDENTICAL_RULE_OVERLAP"),
  )
}
