///|
fn enum_table_r1(
  rules : String,
  domain~ : String = "<inputValues><text>\"M\",\"F\"</text></inputValues>",
  definitions~ : String = "",
  type_name~ : String = "string",
) -> @model.Model raise @types.EngineError {
  @model.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'>" +
    definitions +
    "<inputData id='x' name='x'><variable typeRef='" +
    type_name +
    "'/></inputData><decision id='d' name='d'><decisionTable hitPolicy='UNIQUE'><input><inputExpression><text>x</text></inputExpression>" +
    domain +
    "</input><output/>" +
    rules +
    "</decisionTable></decision></definitions>",
  )
}

///|
fn enum_rule_r1(predicate : String) -> String {
  "<rule><inputEntry><text>" +
  predicate +
  "</text></inputEntry><outputEntry><text>1</text></outputEntry></rule>"
}

///|
test "R1 I6 complete enum has no gap; missing and open domains retain warning" {
  let rules = enum_rule_r1("\"M\"") + enum_rule_r1("\"F\"")
  inspect(@model.lint(enum_table_r1(rules)).stringify(), content="[]")
  inspect(
    @model.lint(enum_table_r1(enum_rule_r1("\"M\"")))
    .stringify()
    .contains("W_POSSIBLE_GAP"),
    content="true",
  )
  inspect(
    @model.lint(enum_table_r1(rules, domain=""))
    .stringify()
    .contains("W_POSSIBLE_GAP"),
    content="true",
  )
  inspect(
    @model.lint(enum_table_r1(enum_rule_r1("\"M\"") + enum_rule_r1("\"M\"")))
    .stringify()
    .contains("W_IDENTICAL_RULE_OVERLAP"),
    content="true",
  )
}

///|
test "R1 I6 ItemDefinition alias allowedValues prove range coverage" {
  let definitions = "<itemDefinition name='Base'><typeRef>number</typeRef><allowedValues><text>1,2,3</text></allowedValues></itemDefinition><itemDefinition name='Alias'><typeRef>Base</typeRef></itemDefinition>"
  inspect(
    @model.lint(
      enum_table_r1(
        enum_rule_r1("[1..3]"),
        definitions~,
        type_name="Alias",
        domain="",
      ),
    ).stringify(),
    content="[]",
  )
  inspect(
    @model.lint(
      enum_table_r1(
        enum_rule_r1("[1..2]"),
        definitions~,
        type_name="Alias",
        domain="",
      ),
    )
    .stringify()
    .contains("W_POSSIBLE_GAP"),
    content="true",
  )
}
