///|
test "Decision table default output must be in the same declared output domain" {
  let invalid_default = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable><input><inputExpression><text>1</text></inputExpression></input><output><outputValues><text>2,3</text></outputValues><defaultOutputEntry><text>9</text></defaultOutputEntry></output><rule><inputEntry><text>0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
        ),
        "demo",
        Map([]),
      ),
    )
    false
  } catch {
    @types.Failure("E_OUTPUT_VALUES", _, _, _) => true
    e => raise e
  }
  assert_true(invalid_default)
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable><input><inputExpression><text>1</text></inputExpression></input><output><outputValues><text>2,3</text></outputValues><defaultOutputEntry><text>3</text></defaultOutputEntry></output><rule><inputEntry><text>0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "demo",
      Map([]),
    ).text(),
    "3",
  )
}
