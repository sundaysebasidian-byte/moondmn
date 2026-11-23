///|
test "Reused table tests keep runtime values and lazy errors" {
  let m = @model.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision name='d' id='d'><decisionTable hitPolicy='FIRST'><input><inputExpression><text>x</text></inputExpression></input><output><defaultOutputEntry><text>0</text></defaultOutputEntry></output><rule><inputEntry><text>> cutoff</text></inputEntry><outputEntry><text>x + 1</text></outputEntry></rule><rule><inputEntry><text>? &lt; 0</text></inputEntry><outputEntry><text>20</text></outputEntry></rule></decisionTable></decision></definitions>",
  )
  let n = i => @types.Number(@types.decimal_int(i))
  assert_eq(
    @model.evaluate_decision(m, "d", Map([("x", n(5)), ("cutoff", n(4))])).text(),
    "6",
  )
  assert_eq(
    @model.evaluate_decision(m, "d", Map([("x", n(5)), ("cutoff", n(6))])).text(),
    "0",
  )
  assert_eq(
    @model.evaluate_decision(m, "d", Map([("x", n(-2)), ("cutoff", n(6))])).text(),
    "20",
  )
  let shaped = @model.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision name='d' id='d'><decisionTable hitPolicy='FIRST'><input><inputExpression><text>x</text></inputExpression></input><output><defaultOutputEntry><text>0</text></defaultOutputEntry></output><rule><inputEntry><text>&gt; a-b</text></inputEntry><outputEntry><text>13</text></outputEntry></rule></decisionTable></decision></definitions>",
  )
  let one_name = Map([("x", n(5)), ("a-b", n(8))])
  assert_eq(@model.evaluate_decision(shaped, "d", one_name).text(), "0")
  assert_eq(
    @model.evaluate_decision(
      shaped,
      "d",
      Map([("x", n(5)), ("a", n(6)), ("b", n(3))]),
    ).text(),
    "13",
  )
  assert_eq(@model.evaluate_decision(shaped, "d", one_name).text(), "0")
  let deferred_model = @model.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision name='d' id='d'><decisionTable hitPolicy='FIRST'><input><inputExpression><text>x</text></inputExpression></input><output><defaultOutputEntry><text>0</text></defaultOutputEntry></output><rule><inputEntry><text>1</text></inputEntry><outputEntry><text>99</text></outputEntry></rule><rule><inputEntry><text>(</text></inputEntry><outputEntry><text>88</text></outputEntry></rule></decisionTable></decision></definitions>",
  )
  assert_eq(
    @model.evaluate_decision(deferred_model, "d", Map([("x", n(1))])).text(),
    "99",
  )
  assert_eq(
    @model.evaluate_decision(deferred_model, "d", Map([("x", n(1))])).text(),
    "99",
  )
  let reached = try {
    ignore(@model.evaluate_decision(deferred_model, "d", Map([("x", n(2))])))
    false
  } catch {
    _ => true
  }
  assert_true(reached)
  let clock_model = @model.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision name='d' id='d'><decisionTable hitPolicy='FIRST'><input><inputExpression><text>x</text></inputExpression></input><output><defaultOutputEntry><text>0</text></defaultOutputEntry></output><rule><inputEntry><text>? = today()</text></inputEntry><outputEntry><text>34</text></outputEntry></rule></decisionTable></decision></definitions>",
  )
  let clock_a = @types.parse_datetime("2024-01-03T12:00:00Z")
  let clock_b = @types.parse_datetime("2024-01-04T12:00:00Z")
  let inputs = Map([("x", @types.Date(@types.parse_date("2024-01-03")))])
  assert_eq(
    @model.evaluate_decision(
      clock_model,
      "d",
      @eval.with_clock(inputs, Some(() => clock_a)),
    ).text(),
    "34",
  )
  assert_eq(
    @model.evaluate_decision(
      clock_model,
      "d",
      @eval.with_clock(inputs, Some(() => clock_b)),
    ).text(),
    "0",
  )
}
