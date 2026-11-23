///|
test "Lint flags missing knowledge links alongside missing information links" {
  let invalid = @model.lint(
    @model.parse_model(
      "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><decision name='demo' id='d'><knowledgeRequirement><requiredKnowledge href='#unknown-bkm'/></knowledgeRequirement><literalExpression><text>3</text></literalExpression></decision></definitions>",
    ),
  ).stringify()
  assert_true(invalid.contains("E_REFERENCE"))
  assert_true(invalid.contains("#unknown-bkm"))
  let good = @model.lint(
    @model.parse_model(
      "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><businessKnowledgeModel id='b' name='bkm'><encapsulatedLogic><literalExpression><text>3</text></literalExpression></encapsulatedLogic></businessKnowledgeModel><decision name='demo' id='d'><knowledgeRequirement><requiredKnowledge href='#b'/></knowledgeRequirement><literalExpression><text>bkm()</text></literalExpression></decision></definitions>",
    ),
  ).stringify()
  assert_true(!good.contains("E_REFERENCE"))

  assert_true(
    @model.lint(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151'><decision name='other' id='wrong'><literalExpression><text>1</text></literalExpression></decision><decision name='demo' id='d'><knowledgeRequirement><requiredKnowledge href='#wrong'/></knowledgeRequirement><literalExpression><text>3</text></literalExpression></decision></definitions>",
      ),
    )
    .stringify()
    .contains("E_REFERENCE"),
  )
  assert_true(
    !@model.lint(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151'><decisionService id='s' name='svc'><outputDecision href='#out'/></decisionService><decision name='out' id='out'><literalExpression><text>1</text></literalExpression></decision><decision name='demo' id='d'><knowledgeRequirement><requiredKnowledge href='#s'/></knowledgeRequirement><literalExpression><text>3</text></literalExpression></decision></definitions>",
      ),
    )
    .stringify()
    .contains("E_REFERENCE"),
  )
  let linked = @model.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151'><import name='q' namespace='urn:child' importType='https://www.omg.org/spec/DMN/20230324/MODEL/' locationURI='child.dmn'/><decision name='demo' id='d'><knowledgeRequirement><requiredKnowledge href='urn:child#b'/></knowledgeRequirement><literalExpression><text>3</text></literalExpression></decision></definitions>",
    resolver=Some((_, _) => {
      "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:child'><businessKnowledgeModel id='b' name='bkm'><encapsulatedLogic><literalExpression><text>3</text></literalExpression></encapsulatedLogic></businessKnowledgeModel></definitions>"
    }),
  )
  assert_true(!@model.lint(linked).stringify().contains("E_REFERENCE"))
}
