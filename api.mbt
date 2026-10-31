///|
/// Evaluate FEEL against a JSON object. The optional clock supplies now/today.
pub fn feel_eval(
  source : String,
  context~ : String = "{}",
  clock~ : (() -> @types.DateTime)? = None,
) -> String raise @types.EngineError {
  @eval.feel_eval(
    source,
    ctx=@eval.with_clock(@types.json_context(context), clock),
  )
  .json()
  .stringify()
}

///|
/// Parse DMN 1.3/1.4/1.5 XML; failures carry code, line and column.
pub fn parse_model(xml : String) -> @model.Model raise @types.EngineError {
  @model.parse_model(xml)
}

///|
/// Evaluate a named decision with exact JSON numbers and an optional clock.
pub fn evaluate_decision(
  model : @model.Model,
  name : String,
  input : String,
  clock~ : (() -> @types.DateTime)? = None,
) -> String raise @types.EngineError {
  @model.evaluate_decision(
    model,
    name,
    @eval.with_clock(@model.json_inputs(model, input), clock),
  )
  .json()
  .stringify()
}

///|
/// Compile FEEL once; include input names containing spaces in names.
pub fn compile(
  source : String,
  names~ : Array[String] = [],
) -> @parser.Expr raise @types.EngineError {
  let scope = @builtins.lexer_names()
  scope.append(names)
  @parser.compile(source, names=scope)
}

///|
/// Reuse a compiled expression with fresh JSON input and optional clock.
pub fn evaluate_compiled(
  expression : @parser.Expr,
  input : String,
  clock~ : (() -> @types.DateTime)? = None,
) -> String raise @types.EngineError {
  @eval.evaluate(
    expression,
    @eval.with_clock(@types.json_context(input), clock),
  )
  .json()
  .stringify()
}
