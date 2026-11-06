///|
/// Evaluate FEEL against a JSON object. The optional clock supplies now/today.
pub fn feel_eval(
  source : String,
  context~ : String = "{}",
  host~ : Map[String, @types.Value] = Map([]),
  clock~ : (() -> @types.DateTime)? = None,
) -> String raise @types.EngineError {
  @eval.feel_eval(
    source,
    ctx=@eval.with_clock(host_scope(@types.json_context(context), host), clock),
  )
  .json()
  .stringify()
}

///|
/// Parse DMN 1.3/1.4/1.5 XML; failures carry code, line and column.
pub fn parse_model(
  xml : String,
  resolver~ : ((String, String) -> String raise @types.EngineError)? = None,
) -> @model.Model raise @types.EngineError {
  @model.parse_model(xml, resolver~)
}

///|
/// Evaluate a named decision with exact JSON numbers and an optional clock.
pub fn evaluate_decision(
  model : @model.Model,
  name : String,
  input : String,
  host~ : Map[String, @types.Value] = Map([]),
  clock~ : (() -> @types.DateTime)? = None,
) -> String raise @types.EngineError {
  @model.evaluate_decision(
    model,
    name,
    @eval.with_clock(host_scope(@model.json_inputs(model, input), host), clock),
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

///|
/// Register a callback in a host scope passed to feel_eval/evaluate_decision.
pub fn register_external(
  host : Map[String, @types.Value],
  class_name : String,
  signature : String,
  callback : (Array[@types.Value]) -> @types.Value raise @types.EngineError,
) -> Unit {
  @eval.register_external(host, class_name, signature, callback)
}

///|
fn host_scope(
  inputs : Map[String, @types.Value],
  host : Map[String, @types.Value],
) -> Map[String, @types.Value] {
  if host.get("$external") is Some(v) {
    inputs["$external"] = v
  }
  inputs
}
