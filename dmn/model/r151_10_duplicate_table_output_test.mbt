///|
test "Compound decision tables reject duplicate logical output names" {
  let duplicate = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable><output name='rate'/><output name='rate'/><rule><outputEntry><text>1</text></outputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
        ),
        "demo",
        Map([]),
      ),
    )
    false
  } catch {
    @types.Failure("E_TABLE_SHAPE", _, _, _) => true
    e => raise e
  }
  assert_true(duplicate)
  assert_true(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><decisionTable><output name='rate'/><output name='tax'/><rule><outputEntry><text>1</text></outputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "demo",
      Map([]),
    ).equals(
      @types.Context(
        Map([
          ("rate", @types.Number(@types.decimal_int(1))),
          ("tax", @types.Number(@types.decimal_int(2))),
        ]),
      ),
    ),
  )
}
