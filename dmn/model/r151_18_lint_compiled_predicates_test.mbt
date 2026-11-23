///|
test "Lint reuses reached unary tests without changing coverage decisions" {
  fn check(tests : String) -> Bool raise @types.EngineError {
    let doc = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable><input><inputExpression><text>x</text></inputExpression><inputValues><text>0,1,2</text></inputValues></input><output/>" +
      tests +
      "</decisionTable></decision></definitions>"
    @model.lint(@model.parse_model(doc)).stringify().contains("W_POSSIBLE_GAP")
  }
  let complete = "<rule><inputEntry><text>? &gt;= 0</text></inputEntry><outputEntry><text>1</text></outputEntry></rule>"
  let malformed = "<rule><inputEntry><text>(</text></inputEntry><outputEntry><text>2</text></outputEntry></rule>"
  assert_true(!check(complete))
  assert_true(!check(complete + malformed))
  assert_true(check(malformed + complete))
  assert_true(check(complete.replace_all(old="&gt;=", new="&gt;")))
}
