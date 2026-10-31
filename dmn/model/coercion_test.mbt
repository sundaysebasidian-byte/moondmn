///|
test "singleton collection" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><itemDefinition name='T' isCollection='true'><typeRef>number</typeRef></itemDefinition><decision id='d' name='d'><variable typeRef='T'/><literalExpression><text>1</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    )
    .json()
    .stringify(),
    content="[1]",
  )
}

///|
test "unwrap singleton" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><variable typeRef='number'/><literalExpression><text>[1]</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    )
    .json()
    .stringify(),
    content="1",
  )
}

///|
test "date promotion" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><variable typeRef='date and time'/><literalExpression><text>date(2024,2,29)</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    )
    .json()
    .stringify(),
    content="\"2024-02-29T00:00:00Z\"",
  )
}

///|
test "collection alias" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><itemDefinition name='T' isCollection='true'><typeRef>number</typeRef></itemDefinition><decision id='d' name='d'><variable typeRef='T'/><literalExpression><text>[1,2]</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    )
    .json()
    .stringify(),
    content="[1,2]",
  )
}
