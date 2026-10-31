///|
test "FIRST " {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='FIRST' aggregation=''><input><inputExpression><text>n</text></inputExpression></input><output><outputValues><text>2,1</text></outputValues></output><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>1</text></outputEntry></rule><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      @types.json_context("{\"n\":1}"),
    )
    .json()
    .stringify(),
    content="1",
  )
}

///|
test "RULE ORDER " {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='RULE ORDER' aggregation=''><input><inputExpression><text>n</text></inputExpression></input><output><outputValues><text>2,1</text></outputValues></output><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>1</text></outputEntry></rule><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      @types.json_context("{\"n\":1}"),
    )
    .json()
    .stringify(),
    content="[1,2]",
  )
}

///|
test "COLLECT " {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='COLLECT' aggregation=''><input><inputExpression><text>n</text></inputExpression></input><output><outputValues><text>2,1</text></outputValues></output><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>1</text></outputEntry></rule><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      @types.json_context("{\"n\":1}"),
    )
    .json()
    .stringify(),
    content="[1,2]",
  )
}

///|
test "COLLECT SUM" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='COLLECT' aggregation='SUM'><input><inputExpression><text>n</text></inputExpression></input><output><outputValues><text>2,1</text></outputValues></output><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>1</text></outputEntry></rule><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      @types.json_context("{\"n\":1}"),
    )
    .json()
    .stringify(),
    content="3",
  )
}

///|
test "COLLECT MIN" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='COLLECT' aggregation='MIN'><input><inputExpression><text>n</text></inputExpression></input><output><outputValues><text>2,1</text></outputValues></output><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>1</text></outputEntry></rule><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      @types.json_context("{\"n\":1}"),
    )
    .json()
    .stringify(),
    content="1",
  )
}

///|
test "COLLECT MAX" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='COLLECT' aggregation='MAX'><input><inputExpression><text>n</text></inputExpression></input><output><outputValues><text>2,1</text></outputValues></output><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>1</text></outputEntry></rule><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      @types.json_context("{\"n\":1}"),
    )
    .json()
    .stringify(),
    content="2",
  )
}

///|
test "COLLECT COUNT" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='COLLECT' aggregation='COUNT'><input><inputExpression><text>n</text></inputExpression></input><output><outputValues><text>2,1</text></outputValues></output><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>1</text></outputEntry></rule><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      @types.json_context("{\"n\":1}"),
    )
    .json()
    .stringify(),
    content="2",
  )
}

///|
test "PRIORITY " {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='PRIORITY' aggregation=''><input><inputExpression><text>n</text></inputExpression></input><output><outputValues><text>2,1</text></outputValues></output><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>1</text></outputEntry></rule><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      @types.json_context("{\"n\":1}"),
    )
    .json()
    .stringify(),
    content="2",
  )
}

///|
test "OUTPUT ORDER " {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='OUTPUT ORDER' aggregation=''><input><inputExpression><text>n</text></inputExpression></input><output><outputValues><text>2,1</text></outputValues></output><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>1</text></outputEntry></rule><rule><inputEntry><text>&gt;0</text></inputEntry><outputEntry><text>2</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      @types.json_context("{\"n\":1}"),
    )
    .json()
    .stringify(),
    content="[2,1]",
  )
}
