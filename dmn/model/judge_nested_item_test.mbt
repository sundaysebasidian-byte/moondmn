///|
test "Named instance-of types retain nested itemComponent shapes and collection fields" {
  let def = "<itemDefinition name='Record'><itemComponent name='items' isCollection='true' typeRef='number'/><itemComponent name='info'><itemComponent name='label' typeRef='string'/></itemComponent></itemDefinition>"
  for (input, expected) in [("{items:[1,2],info:{label:\"x\"}}", "true"), ("{items:1,info:{label:\"x\"}}","false"), ("{items:[1],info:{label:9}}","false"), ("{items:[1],info:17}","false")] {
    let xml = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'>" + def + "<decision name='d' id='d'><literalExpression><text>" + input + " instance of Record</text></literalExpression></decision></definitions>"
    assert_eq(@model.evaluate_decision(@model.parse_model(xml),"d",Map([])).text(), expected)
  }
}
