///|
fn java_boxed(
  model : Model,
  body : @xml.Node,
  scope : Map[String, @types.Value],
  args : Array[@types.Value],
) -> @types.Value raise @types.EngineError {
  @eval.invoke_external(
    Context(Map([("java", boxed(model, body, scope))])),
    args,
    scope,
  ) catch {
    @types.Failure(code, _, _, message) =>
      raise @types.Failure(code, body.line, body.column, message)
  }
}
