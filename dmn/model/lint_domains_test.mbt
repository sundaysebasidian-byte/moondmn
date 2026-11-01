///|
fn enum_table(
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
fn enum_rule(predicate : String) -> String {
  "<rule><inputEntry><text>" +
  predicate +
  "</text></inputEntry><outputEntry><text>1</text></outputEntry></rule>"
}

///|
test "complete enum has no gap; missing and open domains retain warning" {
  let rules = enum_rule("\"M\"") + enum_rule("\"F\"")
  inspect(@model.lint(enum_table(rules)).stringify(), content="[]")
  inspect(
    @model.lint(enum_table(enum_rule("\"M\"")))
    .stringify()
    .contains("W_POSSIBLE_GAP"),
    content="true",
  )
  inspect(
    @model.lint(enum_table(rules, domain=""))
    .stringify()
    .contains("W_POSSIBLE_GAP"),
    content="true",
  )
  inspect(
    @model.lint(enum_table(enum_rule("\"M\"") + enum_rule("\"M\"")))
    .stringify()
    .contains("W_IDENTICAL_RULE_OVERLAP"),
    content="true",
  )
}

///|
test "ItemDefinition alias allowedValues prove range coverage" {
  let definitions = "<itemDefinition name='Base'><typeRef>number</typeRef><allowedValues><text>1,2,3</text></allowedValues></itemDefinition><itemDefinition name='Alias'><typeRef>Base</typeRef></itemDefinition>"
  inspect(
    @model.lint(
      enum_table(
        enum_rule("[1..3]"),
        definitions~,
        type_name="Alias",
        domain="",
      ),
    ).stringify(),
    content="[]",
  )
  inspect(
    @model.lint(
      enum_table(
        enum_rule("[1..2]"),
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
