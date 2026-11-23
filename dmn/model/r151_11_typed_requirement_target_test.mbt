///|
test "Requirement hrefs must refer to the declared kind of model element" {
  let local_kind = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><businessKnowledgeModel name='bk' id='b'><encapsulatedLogic><literalExpression><text>7</text></literalExpression></encapsulatedLogic></businessKnowledgeModel><decision name='demo' id='d'><informationRequirement><requiredDecision href='#b'/></informationRequirement><literalExpression><text>1</text></literalExpression></decision></definitions>",
        ),
        "demo",
        Map([]),
      ),
    )
    false
  } catch {
    @types.Failure("E_REFERENCE", _, _, _) => true
    e => raise e
  }
  assert_true(local_kind)
  let imported_kind = try {
    ignore(
      @model.evaluate_decision(
        @model.parse_model(
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><import name='org' namespace='urn:child' locationURI='child.dmn' importType='https://www.omg.org/spec/DMN/20230324/MODEL/'/><decision name='demo' id='d'><informationRequirement><requiredDecision href='urn:child#i'/></informationRequirement><literalExpression><text>1</text></literalExpression></decision></definitions>",
          resolver=Some((_, _) => {
            "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:child' ><inputData name='tax' id='i'><variable typeRef='number'/></inputData></definitions>"
          }),
        ),
        "demo",
        Map([]),
      ),
    )
    false
  } catch {
    @types.Failure("E_REFERENCE", _, _, _) => true
    e => raise e
  }
  assert_true(imported_kind)
  assert_eq(
    @model.evaluate_decision(
      @model.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><inputData name='tax' id='i'><variable typeRef='number'/></inputData><decision name='demo' id='d'><informationRequirement><requiredInput href='#i'/></informationRequirement><literalExpression><text>tax</text></literalExpression></decision></definitions>",
      ),
      "demo",
      Map([("tax", @types.Number(@types.decimal_int(9)))]),
    ).text(),
    "9",
  )

  let local_short = @model.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151'><inputData id='i'/><decision id='d' name='demo'><informationRequirement><requiredInput href='#i'/></informationRequirement><literalExpression><text>i</text></literalExpression></decision></definitions>",
  )
  let nine = @types.Number(@types.decimal_int(9))
  assert_eq(
    @model.evaluate_decision(local_short, "demo", Map([("i", nine)])).text(),
    "9",
  )
  let imported_short = @model.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151'><import name='org' namespace='urn:child' importType='https://www.omg.org/spec/DMN/20230324/MODEL/' locationURI='child.dmn'/><decision id='d' name='demo'><informationRequirement><requiredInput href='urn:child#i'/></informationRequirement><literalExpression><text>org.i</text></literalExpression></decision></definitions>",
    resolver=Some((_, _) => {
      "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:child'><inputData id='i'/></definitions>"
    }),
  )
  assert_eq(
    @model.evaluate_decision(
      imported_short,
      "demo",
      Map([("org", @types.Context(Map([("i", nine)])))]),
    ).text(),
    "9",
  )
}
