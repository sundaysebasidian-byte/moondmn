///|
test "Collect MIN and MAX use FEEL ordering for comparable outputs" {
  for
    (op, a, b, expected) in [
      ("MIN", "date(2025,3,1)", "date(2024,12,31)", "2024-12-31"),
      ("MAX", "\"amber\"", "\"black\"", "black"),
      ("MIN", "2", "3", "2"),
      ("MIN", "1", "\"a\"", "E_TABLE_AGGREGATION"),
      ("SUM", "\"1\"", "\"2\"", "E_TABLE_AGGREGATION"),
    ] {
    let xml = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision name='d' id='d'><decisionTable hitPolicy='COLLECT' aggregation='" +
      op +
      "'><output/><rule><outputEntry><text>" +
      a +
      "</text></outputEntry></rule><rule><outputEntry><text>" +
      b +
      "</text></outputEntry></rule></decisionTable></decision></definitions>"
    let result = @model.evaluate_decision(@model.parse_model(xml), "d", Map([])).text() catch {
      e => @types.error_code(e)
    }
    assert_eq(result, expected)
  }
}
