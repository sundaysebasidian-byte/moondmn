///|
fn json_model(
  type_name : String,
  expression : String,
  definitions~ : String = "",
) -> @model.Model raise @types.EngineError {
  @moondmn.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'>" +
    definitions +
    "<inputData id='x' name='x'><variable typeRef='" +
    type_name +
    "'/></inputData><decision id='d' name='d'><informationRequirement><requiredInput href='#x'/></informationRequirement><literalExpression><text>" +
    expression +
    "</text></literalExpression></decision></definitions>",
  )
}

///|
test "JSON temporal inputs share the declared conversion boundary" {
  inspect(
    @moondmn.evaluate_decision(
      json_model("date", "x + duration(\"P1D\")"),
      "d",
      "{\"x\":\"2024-02-28\"}",
    ),
    content="\"2024-02-29\"",
  )
  inspect(
    @moondmn.evaluate_decision(
      json_model("time", "x.hour"),
      "d",
      "{\"x\":\"12:30:00Z\"}",
    ),
    content="12",
  )
  inspect(
    @moondmn.evaluate_decision(
      json_model("date and time", "x.year"),
      "d",
      "{\"x\":\"2024-02-29T12:30:00Z\"}",
    ),
    content="2024",
  )
  inspect(
    @moondmn.evaluate_decision(
      json_model("days and time duration", "x.days"),
      "d",
      "{\"x\":\"P2D\"}",
    ),
    content="2",
  )
  inspect(
    @moondmn.evaluate_decision(
      json_model("years and months duration", "x.months"),
      "d",
      "{\"x\":\"P1Y2M\"}",
    ),
    content="2",
  )
  inspect(
    @moondmn.evaluate_decision(json_model("date", "x"), "d", "{\"x\":null}"),
    content="null",
  )
  let code = try {
    ignore(
      @moondmn.evaluate_decision(
        json_model("date", "x"),
        "d",
        "{\"x\":\"2023-02-29\"}",
      ),
    )
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_DATE_INVALID")
}

///|
test "nested collections aliases and precise numbers" {
  let definitions = "<itemDefinition name='Dates' isCollection='true'><typeRef>date</typeRef></itemDefinition><itemDefinition name='T'><itemComponent name='Business Dates' typeRef='Dates'/><itemComponent name='Amount' typeRef='number'/></itemDefinition>"
  let model = json_model(
    "T",
    "[x.Business Dates[1].day, x.Amount]",
    definitions~,
  )
  inspect(
    @moondmn.evaluate_decision(
      model, "d", "{\"x\":{\"Business Dates\":[\"2024-02-29\",null],\"Amount\":1234567890123456789012345678901234}}",
    ),
    content="[29,1234567890123456789012345678901234]",
  )
}
