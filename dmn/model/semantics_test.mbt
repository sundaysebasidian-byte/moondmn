// Expectations follow DMN 1.5 clauses 10.3.2 and 10.4.

///|
test "expression return coercion" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:test'><itemDefinition name='Nums' isCollection='true'><typeRef>number</typeRef></itemDefinition><decision name='d' id='d'><variable /><literalExpression typeRef='Nums'><text>1</text></literalExpression></decision></definitions>",
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
test "context variable coercion" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:test'><itemDefinition name='Nums' isCollection='true'><typeRef>number</typeRef></itemDefinition><decision name='d' id='d'><variable /><context><contextEntry><variable name='x' typeRef='Nums'/><literalExpression ><text>1</text></literalExpression></contextEntry><contextEntry><literalExpression ><text>x</text></literalExpression></contextEntry></context></decision></definitions>",
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
test "preserve nested Any collections" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:test'><itemDefinition name='AnyList' isCollection='true'><typeRef>Any</typeRef></itemDefinition><decision name='d' id='d'><variable typeRef='AnyList'/><literalExpression ><text>[[1],2]</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    )
    .json()
    .stringify(),
    content="[[1],2]",
  )
}

///|
test "missing declared fields" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:test'><itemDefinition name='Pair'><itemComponent name='a' typeRef='number'/><itemComponent name='b' typeRef='number'/></itemDefinition><decision name='d' id='d'><variable typeRef='Pair'/><literalExpression ><text>{a:1}</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    )
    .json()
    .stringify(),
    content="null",
  )
}

///|
test "service declaration order" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:test'><inputData name='a' id='a'/><decision name='b' id='b'/><decisionService name='svc' id='svc'><outputDecision href='#out'/><inputDecision href='#b'/><inputData href='#a'/></decisionService><decision name='out' id='out'><informationRequirement><requiredInput href='#a'/></informationRequirement><informationRequirement><requiredDecision href='#b'/></informationRequirement><literalExpression ><text>a+b</text></literalExpression></decision><decision name='d' id='d'><variable /><knowledgeRequirement><requiredKnowledge href='#svc'/></knowledgeRequirement><literalExpression ><text>svc(2,3)</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    )
    .json()
    .stringify(),
    content="5",
  )
}

///|
test "boxed scalar quantified domain" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:test'><decision name='d' id='d'><variable /><some iteratorVariable='x'><in><literalExpression ><text>2</text></literalExpression></in><satisfies><literalExpression ><text>x > 1</text></literalExpression></satisfies></some></decision></definitions>",
      ),
      "d",
      Map([]),
    )
    .json()
    .stringify(),
    content="true",
  )
}

///|
test "boxed invalid predicate" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:test'><decision name='d' id='d'><variable /><filter><in><literalExpression ><text>[1,2]</text></literalExpression></in><match><literalExpression ><text>\"bad\"</text></literalExpression></match></filter></decision></definitions>",
      ),
      "d",
      Map([]),
    )
    .json()
    .stringify(),
    content="null",
  )
}

///|
test "table collect default" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:test'><decision name='d' id='d'><variable /><decisionTable hitPolicy='COLLECT' aggregation='MAX'><input><inputExpression><text>0</text></inputExpression></input><output><defaultOutputEntry><text>7</text></defaultOutputEntry></output><rule><inputEntry><text>1</text></inputEntry><outputEntry><text>9</text></outputEntry></rule></decisionTable></decision></definitions>",
      ),
      "d",
      Map([]),
    )
    .json()
    .stringify(),
    content="7",
  )
}

///|
test "absolute local reference" {
  inspect(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:test'><decision name='a' id='a'><literalExpression ><text>2</text></literalExpression></decision><decision name='d' id='d'><variable /><informationRequirement><requiredDecision href='urn:test#a'/></informationRequirement><literalExpression ><text>a+1</text></literalExpression></decision></definitions>",
      ),
      "d",
      Map([]),
    )
    .json()
    .stringify(),
    content="3",
  )
}
