///|
test "Lint uses imported named type enumerations for coverage" {
  let imported = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:child'><itemDefinition name='Choice' typeRef='string'><allowedValues><text>\"y\",\"n\"</text></allowedValues></itemDefinition></definitions>"
  let main = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:r151' ><import name='org' namespace='urn:child' locationURI='child.dmn' importType='https://www.omg.org/spec/DMN/20230324/MODEL/'/><inputData id='in' name='x'><variable typeRef='org.Choice'/></inputData><decision name='demo' id='d'><decisionTable><input><inputExpression><text>x</text></inputExpression></input><output/><rule><inputEntry><text>\"y\"</text></inputEntry><outputEntry><text>3</text></outputEntry></rule><rule><inputEntry><text>\"n\"</text></inputEntry><outputEntry><text>4</text></outputEntry></rule></decisionTable></decision></definitions>"
  let model = @model.parse_model(main, resolver=Some((_, _) => imported))
  assert_true(!@model.lint(model).stringify().contains("W_POSSIBLE_GAP"))
  let limited = @model.parse_model(
    main.replace_all(
      old="<rule><inputEntry><text>\"n\"</text></inputEntry><outputEntry><text>4</text></outputEntry></rule>",
      new="",
    ),
    resolver=Some((_, _) => imported),
  )
  assert_true(@model.lint(limited).stringify().contains("W_POSSIBLE_GAP"))
}
