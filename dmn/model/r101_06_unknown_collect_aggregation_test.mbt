///|
test "Invalid Collect aggregation cannot pass with one or no match" {
  let bad_1 = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><decisionTable hitPolicy='COLLECT' aggregation='MEDIAN'><input><inputExpression><text>1</text></inputExpression></input><output/><rule><inputEntry><text>1</text></inputEntry><outputEntry><text>9</text></outputEntry></rule></decisionTable></decision></definitions>",
        ),
        "d",
        Map([]),
      ),
    )
    false
  } catch {
    @types.Failure("E_TABLE_AGGREGATION", _, _, _) => true
    e => raise e
  }
  assert_true(bad_1)
  let bad_2 = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><decisionTable hitPolicy='COLLECT' aggregation='MEDIAN'><input><inputExpression><text>1</text></inputExpression></input><output/><rule><inputEntry><text>2</text></inputEntry><outputEntry><text>9</text></outputEntry></rule></decisionTable></decision></definitions>",
        ),
        "d",
        Map([]),
      ),
    )
    false
  } catch {
    @types.Failure("E_TABLE_AGGREGATION", _, _, _) => true
    e => raise e
  }
  assert_true(bad_2)
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><decisionTable hitPolicy='COLLECT' aggregation='SUM'><input><inputExpression><text>1</text></inputExpression></input><output/><rule><inputEntry><text>1</text></inputEntry><outputEntry><text>9</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "9",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><decisionTable hitPolicy='COLLECT'><input><inputExpression><text>1</text></inputExpression></input><output/><rule><inputEntry><text>1</text></inputEntry><outputEntry><text>9</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "[9]",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><decisionTable hitPolicy='COLLECT' aggregation='COUNT'><input><inputExpression><text>1</text></inputExpression></input><output/><rule><inputEntry><text>2</text></inputEntry><outputEntry><text>9</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "0",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r101'><decision id='d' name='d'><decisionTable hitPolicy='C+'><input><inputExpression><text>1</text></inputExpression></input><output/><rule><inputEntry><text>1</text></inputEntry><outputEntry><text>9</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "9",
  )
}
