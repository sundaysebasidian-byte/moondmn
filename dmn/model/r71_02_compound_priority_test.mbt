///|
test "Compound output priority breaks ties across ranked columns" {
  let base = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='"
  let body = "'><output name='label'/><output name='size'><outputValues><text>2,1</text></outputValues></output><output name='score'><outputValues><text>8,9</text></outputValues></output><rule><outputEntry><text>\"A\"</text></outputEntry><outputEntry><text>1</text></outputEntry><outputEntry><text>8</text></outputEntry></rule><rule><outputEntry><text>\"B\"</text></outputEntry><outputEntry><text>2</text></outputEntry><outputEntry><text>9</text></outputEntry></rule><rule><outputEntry><text>\"C\"</text></outputEntry><outputEntry><text>2</text></outputEntry><outputEntry><text>8</text></outputEntry></rule><rule><outputEntry><text>\"D\"</text></outputEntry><outputEntry><text>2</text></outputEntry><outputEntry><text>8</text></outputEntry></rule></decisionTable></decision></definitions>"
  let order = @model.evaluate_decision(
    @model.parse_model(base + "OUTPUT ORDER" + body),
    "d",
    Map([]),
  )
  let chosen = @model.evaluate_decision(
    @model.parse_model(base + "PRIORITY" + body),
    "d",
    Map([]),
  )
  assert_true(
    order.equals(
      @types.json_context(
        "{\"expected\":[{\"label\":\"C\",\"size\":2,\"score\":8},{\"label\":\"D\",\"size\":2,\"score\":8},{\"label\":\"B\",\"size\":2,\"score\":9},{\"label\":\"A\",\"size\":1,\"score\":8}]}",
      )["expected"],
    ),
  )
  assert_true(
    chosen.equals(
      @types.json_context(
        "{\"expected\":{\"label\":\"C\",\"size\":2,\"score\":8}}",
      )["expected"],
    ),
  )
}
