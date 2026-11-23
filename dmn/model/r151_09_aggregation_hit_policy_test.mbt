///|
test "Lint reports aggregation ignored by non-Collect policies without changing evaluation" {
  let sample = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='UNIQUE' aggregation='SUM'><output/><rule><outputEntry><text>3</text></outputEntry></rule></decisionTable></decision></definitions>"
  let unique = @model.parse_model(sample)
  assert_true(@model.lint(unique).stringify().contains("W_IGNORED_AGGREGATION"))
  assert_eq(@model.evaluate_decision(unique, "d", Map([])).text(), "3")
  let collect = @model.parse_model(
    sample.replace_all(old="UNIQUE", new="COLLECT"),
  )
  assert_true(
    !@model.lint(collect).stringify().contains("W_IGNORED_AGGREGATION"),
  )
  assert_eq(@model.evaluate_decision(collect, "d", Map([])).text(), "3")
}
