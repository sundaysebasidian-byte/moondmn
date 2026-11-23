///|
test "Unsupported boxed function kinds are not interpreted as FEEL" {
  let blocked_0 = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><invocation><functionDefinition kind='PMML'><formalParameter name='x'/><literalExpression ><text>x+1</text></literalExpression></functionDefinition><binding><parameter name='x'/><literalExpression ><text>2</text></literalExpression></binding></invocation></decision></definitions>",
        ),
        "d",
        Map([]),
      ).text(),
    )
    false
  } catch {
    @types.Failure("E_DMN_UNSUPPORTED", _, _, _) => true
    e => raise e
  }
  assert_true(blocked_0)
  let blocked_1 = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><invocation><functionDefinition kind='Other'><formalParameter name='x'/><literalExpression ><text>x+1</text></literalExpression></functionDefinition><binding><parameter name='x'/><literalExpression ><text>2</text></literalExpression></binding></invocation></decision></definitions>",
        ),
        "d",
        Map([]),
      ).text(),
    )
    false
  } catch {
    @types.Failure("E_DMN_UNSUPPORTED", _, _, _) => true
    e => raise e
  }
  assert_true(blocked_1)
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:extension' ><decision id='d' name='d'><invocation><functionDefinition kind='FEEL'><formalParameter name='x'/><literalExpression ><text>x+1</text></literalExpression></functionDefinition><binding><parameter name='x'/><literalExpression ><text>2</text></literalExpression></binding></invocation></decision></definitions>",
      ),
      "d",
      Map([]),
    ).text(),
    "3",
  )
  let fn_host = Map([])
  @eval.register_external(fn_host, "Example", "echo(number)", args => args[0])
  let pmml_bkm_rejected = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><itemDefinition name='FnCollection' isCollection='true'><functionItem outputTypeRef='number'/></itemDefinition><businessKnowledgeModel id='b' name='echo'><variable typeRef='FnCollection'/><encapsulatedLogic kind='PMML'><formalParameter name='x' typeRef='number'/><literalExpression><text>x</text></literalExpression></encapsulatedLogic></businessKnowledgeModel><decision id='d' name='d'><knowledgeRequirement><requiredKnowledge href='#b'/></knowledgeRequirement><literalExpression><text>echo([42])</text></literalExpression></decision></definitions>",
        ),
        "d",
        fn_host,
      ),
    )
    false
  } catch {
    @types.Failure("E_DMN_UNSUPPORTED", _, _, _) => true
    e => raise e
  }
  assert_true(pmml_bkm_rejected)
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><itemDefinition name='FnCollection' isCollection='true'><functionItem outputTypeRef='number'/></itemDefinition><businessKnowledgeModel id='b' name='echo'><variable typeRef='FnCollection'/><encapsulatedLogic><formalParameter name='x' typeRef='number'/><literalExpression><text>x+1</text></literalExpression></encapsulatedLogic></businessKnowledgeModel><decision id='d' name='d'><knowledgeRequirement><requiredKnowledge href='#b'/></knowledgeRequirement><literalExpression><text>echo([42])</text></literalExpression></decision></definitions>",
      ),
      "d",
      fn_host,
    ).text(),
    "43",
  )
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><itemDefinition name='FnCollection' isCollection='true'><functionItem outputTypeRef='number'/></itemDefinition><businessKnowledgeModel id='b' name='echo'><variable typeRef='FnCollection'/><encapsulatedLogic kind='Java'><formalParameter name='x' typeRef='number'/><literalExpression><text>{class: \"Example\", method signature: \"echo(number)\"}</text></literalExpression></encapsulatedLogic></businessKnowledgeModel><decision id='d' name='d'><knowledgeRequirement><requiredKnowledge href='#b'/></knowledgeRequirement><literalExpression><text>echo([42])</text></literalExpression></decision></definitions>",
      ),
      "d",
      fn_host,
    ).text(),
    "42",
  )
}
