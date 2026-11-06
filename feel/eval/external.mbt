///|
/// Register a host function in a caller-owned scope. No process global state.
pub fn register_external(
  ctx : Map[String, @types.Value],
  class_name : String,
  signature : String,
  callback : (Array[@types.Value]) -> @types.Value raise @types.EngineError,
) -> Unit {
  let registry = match ctx.get("$external") {
    Some(Context(c)) => c.copy()
    _ => Map([])
  }
  let methods = match registry.get(class_name) {
    Some(Context(c)) => c.copy()
    _ => Map([])
  }
  methods[signature] = Function({ name: signature, params: [], callback, })
  registry[class_name] = Context(methods)
  ctx["$external"] = Context(registry)
}

///|
/// Invoke an explicitly registered Java descriptor using already converted FEEL values.
pub fn invoke_external(
  descriptor : @types.Value,
  args : Array[@types.Value],
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  let java = match descriptor {
    Context(c) => c.get("java")
    _ => None
  }
  let (class_name, signature) = match java {
    Some(Context(c)) =>
      match (c.get("class"), c.get("method signature")) {
        (Some(Text(a)), Some(Text(b))) => (a, b)
        _ =>
          raise @types.fail(
            "E_EXTERNAL_DESCRIPTOR", "expected Java class and method signature strings",
          )
      }
    _ =>
      raise @types.fail(
        "E_EXTERNAL_DESCRIPTOR", "expected external Java descriptor",
      )
  }
  if ctx.get("$external") is Some(Context(registry)) &&
    registry.get(class_name) is Some(Context(methods)) &&
    methods.get(signature) is Some(Function(f)) {
    return (f.callback)(args)
  }
  raise @types.fail(
    "E_EXTERNAL_UNBOUND",
    "unregistered external function: " + class_name + " :: " + signature,
  )
}
