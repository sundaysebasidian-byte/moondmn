///|
test "Compound OUTPUT ORDER preserves ranked output and source order on ties" {
  let xml = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='OUTPUT ORDER'><output name='tier'><outputValues><text>2,1</text></outputValues></output><output name='ordinal'/>" +
    "<rule><outputEntry><text>1</text></outputEntry><outputEntry><text>0</text></outputEntry></rule>" +
    "<rule><outputEntry><text>2</text></outputEntry><outputEntry><text>1</text></outputEntry></rule>" +
    "<rule><outputEntry><text>1</text></outputEntry><outputEntry><text>2</text></outputEntry></rule>" +
    "<rule><outputEntry><text>2</text></outputEntry><outputEntry><text>3</text></outputEntry></rule>" +
    "</decisionTable></decision></definitions>"
  let result = @model.evaluate_decision(@model.parse_model(xml), "d", Map([]))
  guard result is List(rows) else { fail("expected ordered rows") }
  let ordinals = rows.map(row => {
    guard row is Context(fields) else { panic() }
    fields["ordinal"].text()
  })
  assert_eq(ordinals.join(","), "1,3,0,2")

  let both = @model.evaluate_decision(
    @model.parse_model(
      "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision name='d' id='d'><decisionTable hitPolicy='OUTPUT ORDER'><output name='tier'><outputValues><text>2,1</text></outputValues></output><output name='rank'><outputValues><text>1,2</text></outputValues></output><output name='ordinal'/><rule><outputEntry><text>2</text></outputEntry><outputEntry><text>2</text></outputEntry><outputEntry><text>0</text></outputEntry></rule><rule><outputEntry><text>1</text></outputEntry><outputEntry><text>1</text></outputEntry><outputEntry><text>1</text></outputEntry></rule><rule><outputEntry><text>2</text></outputEntry><outputEntry><text>1</text></outputEntry><outputEntry><text>2</text></outputEntry></rule><rule><outputEntry><text>2</text></outputEntry><outputEntry><text>1</text></outputEntry><outputEntry><text>3</text></outputEntry></rule><rule><outputEntry><text>1</text></outputEntry><outputEntry><text>2</text></outputEntry><outputEntry><text>4</text></outputEntry></rule><rule><outputEntry><text>2</text></outputEntry><outputEntry><text>2</text></outputEntry><outputEntry><text>5</text></outputEntry></rule></decisionTable></decision></definitions>",
    ),
    "d",
    Map([]),
  )
  guard both is List(both_rows) else { fail("expected ordered rows") }
  let both_order = both_rows.map(row => {
    guard row is Context(fields) else { panic() }
    fields["ordinal"].text()
  })
  assert_eq(both_order.join(","), "2,3,0,5,1,4")
}
