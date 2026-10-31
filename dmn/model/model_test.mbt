///|
test "model dependencies and namespace rejection" {
  let m = @model.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><inputData id='i' name='age'/><decision id='d' name='eligible'><informationRequirement><requiredInput href='#i'/></informationRequirement><literalExpression><text>age &gt;= 18</text></literalExpression></decision></definitions>",
  )
  inspect(
    @model.evaluate_decision(m, "eligible", @types.json_context("{\"age\":22}"))
    .json()
    .stringify(),
    content="true",
  )
  assert_true(
    try {
      ignore(@model.evaluate_decision(m, "eligible", Map([])))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@model.parse_model("<definitions xmlns='urn:wrong'/>"))
      false
    } catch {
      _ => true
    },
  )
}
