///|
pub fn feel_eval(
  source : String,
  context~ : String = "{}",
) -> String raise @types.EngineError {
  @eval.feel_eval(source, ctx=@types.json_context(context)).json().stringify()
}

///|
pub fn parse_model(xml : String) -> @model.Model raise @types.EngineError {
  @model.parse_model(xml)
}

///|
pub fn evaluate_decision(
  model : @model.Model,
  name : String,
  input : String,
) -> String raise @types.EngineError {
  @model.evaluate_decision(model, name, @types.json_context(input))
  .json()
  .stringify()
}

///|
pub fn compile(
  source : String,
  names~ : Array[String] = [],
) -> @parser.Expr raise @types.EngineError {
  let scope = @builtins.names()
  scope.append(names)
  @parser.compile(source, names=scope)
}

///|
pub fn evaluate_compiled(
  expression : @parser.Expr,
  input : String,
) -> String raise @types.EngineError {
  @eval.evaluate(expression, @types.json_context(input)).json().stringify()
}
