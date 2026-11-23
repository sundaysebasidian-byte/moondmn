///|
test "Decision-table unary tests honor their own expression language" {
  let rule_rejected = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><decisionTable hitPolicy='FIRST'><input><inputExpression ><text>1</text></inputExpression></input><output></output><rule><inputEntry expressionLanguage='https://example.org/JUEL'><text>1</text></inputEntry><outputEntry ><text>7</text></outputEntry></rule></decisionTable></decision></definitions>",
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
  assert_true(rule_rejected)
  let domain_rejected = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><decisionTable hitPolicy='FIRST'><input><inputExpression ><text>1</text></inputExpression><inputValues expressionLanguage='https://example.org/JUEL'><text>1</text></inputValues></input><output></output><rule><inputEntry ><text>1</text></inputEntry><outputEntry ><text>7</text></outputEntry></rule></decisionTable></decision></definitions>",
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
  assert_true(domain_rejected)
  let outputs_rejected = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><decisionTable hitPolicy='FIRST'><input><inputExpression ><text>1</text></inputExpression></input><output><outputValues expressionLanguage='https://example.org/JUEL'><text>7</text></outputValues></output><rule><inputEntry ><text>1</text></inputEntry><outputEntry ><text>7</text></outputEntry></rule></decisionTable></decision></definitions>",
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
  assert_true(outputs_rejected)
  let inherited_rejected = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' expressionLanguage='https://example.org/JUEL'><decision id='d' name='d'><decisionTable hitPolicy='FIRST'><input><inputExpression expressionLanguage='https://www.omg.org/spec/DMN/20230324/FEEL/'><text>1</text></inputExpression></input><output></output><rule><inputEntry ><text>1</text></inputEntry><outputEntry expressionLanguage='https://www.omg.org/spec/DMN/20230324/FEEL/'><text>7</text></outputEntry></rule></decisionTable></decision></definitions>",
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
  assert_true(inherited_rejected)
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' expressionLanguage='https://example.org/JUEL'><decision id='d' name='d'><decisionTable hitPolicy='FIRST'><input><inputExpression expressionLanguage='https://www.omg.org/spec/DMN/20230324/FEEL/'><text>1</text></inputExpression></input><output></output><rule><inputEntry expressionLanguage='https://www.omg.org/spec/DMN/20230324/FEEL/'><text>1</text></inputEntry><outputEntry expressionLanguage='https://www.omg.org/spec/DMN/20230324/FEEL/'><text>7</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "7",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><decisionTable hitPolicy='FIRST'><input><inputExpression ><text>1</text></inputExpression></input><output></output><rule><inputEntry ><text>1</text></inputEntry><outputEntry ><text>7</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "7",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><decisionTable hitPolicy='FIRST'><input><inputExpression expressionLanguage='  http://www.omg.org/spec/FEEL/20140401  '><text>1</text></inputExpression></input><output></output><rule><inputEntry expressionLanguage='  http://www.omg.org/spec/FEEL/20140401  '><text>1</text></inputEntry><outputEntry expressionLanguage='  http://www.omg.org/spec/FEEL/20140401  '><text>7</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "7",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><decisionTable hitPolicy='FIRST'><input><inputExpression expressionLanguage='  http://www.omg.org/spec/DMN/20180521/FEEL/  '><text>1</text></inputExpression></input><output></output><rule><inputEntry expressionLanguage='  http://www.omg.org/spec/DMN/20180521/FEEL/  '><text>1</text></inputEntry><outputEntry expressionLanguage='  http://www.omg.org/spec/DMN/20180521/FEEL/  '><text>7</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "7",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' expressionLanguage='  https://www.omg.org/spec/DMN/20180521/FEEL/  '><decision id='d' name='d'><literalExpression><text>7</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "7",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' expressionLanguage='  https://www.omg.org/spec/DMN/20180521/FEEL/  '><decision id='d' name='d'><decisionTable hitPolicy='FIRST'><input><inputExpression><text>1</text></inputExpression></input><output/><rule><inputEntry><text>1</text></inputEntry><outputEntry><text>7</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "7",
  )
}
