///|
test "DMN XML boolean forms describe the same collection cardinality" {
  for (flag, expected) in [("1","[2]"), ("true","[2]"), (" 1 ","[2]"), ("0","2"), ("false","2")] {
    let xml = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><itemDefinition name='T' isCollection='" + flag + "'><typeRef>number</typeRef></itemDefinition><decision name='d' id='d'><variable typeRef='T'/><literalExpression><text>2</text></literalExpression></decision></definitions>"
    assert_eq(@model.evaluate_decision(@model.parse_model(xml),"d",Map([])).text(),expected)
  }
}
