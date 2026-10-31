///|
/// Validate supported primitive, collection, alias and structured ItemDefinitions.
/// No implicit coercions are performed in this version.
fn validate_type(
  model : Model,
  type_name : String,
  value : @types.Value,
  depth : Int32,
) -> Unit raise @types.EngineError {
  if depth > 32 {
    raise @types.fail("E_TYPE_CYCLE", "recursive ItemDefinition")
  }
  if value == Null {
    return
  }
  match type_name {
    "" | "Any" | "any" => return
    "number" => if value is Number(_) { return }
    "string" => if value is Text(_) { return }
    "boolean" => if value is Boolean(_) { return }
    _ => {
      for definition in model.root.all("itemDefinition") {
        if definition.attr("name") == type_name {
          validate_definition(model, definition, value, depth + 1, true)
          return
        }
      }
      raise @types.fail(
        "E_TYPE_UNSUPPORTED",
        "unknown or unsupported type: " + type_name,
      )
    }
  }
  raise @types.fail("E_TYPE", "value does not conform to " + type_name)
}

///|
fn validate_definition(
  model : Model,
  node : @xml.Node,
  value : @types.Value,
  depth : Int32,
  collection : Bool,
) -> Unit raise @types.EngineError {
  if depth > 32 {
    raise @types.fail("E_TYPE_CYCLE", "recursive ItemDefinition")
  }
  if collection && node.attr("isCollection") == "true" {
    match value {
      List(xs) =>
        for x in xs {
          validate_definition(model, node, x, depth + 1, false)
        }
      _ =>
        raise @types.fail(
          "E_TYPE_COLLECTION", "expected list; singleton coercion unsupported",
        )
    }
    return
  }
  let components = node.all("itemComponent")
  if !components.is_empty() {
    match value {
      Context(ctx) =>
        for component in components {
          let v = match ctx.get(component.attr("name")) {
            Some(v) => v
            None =>
              raise @types.fail(
                "E_TYPE_FIELD",
                "missing field: " + component.attr("name"),
              )
          }
          validate_definition(model, component, v, depth + 1, true)
        }
      _ => raise @types.fail("E_TYPE", "expected context")
    }
  } else {
    let type_name = if node.attr("typeRef") != "" {
      node.attr("typeRef")
    } else {
      node.content("typeRef")
    }
    validate_type(model, type_name, value, depth + 1)
  }
  if node.child("allowedValues") is Some(allowed) {
    if !@eval.unary_test(allowed.content("text"), value, Map([])) {
      raise @types.fail(
        "E_ALLOWED_VALUES", "ItemDefinition allowedValues violation",
      )
    }
  }
}

///|
fn validate_variable(
  model : Model,
  node : @xml.Node,
  value : @types.Value,
) -> Unit raise @types.EngineError {
  if node.child("variable") is Some(variable) {
    validate_type(model, variable.attr("typeRef"), value, 0)
  }
}
