///|
fn item_type_name(node : @xml.Node) -> String {
  if node.attr("typeRef") != "" {
    node.attr("typeRef")
  } else {
    node.content("typeRef")
  }
}

///|
fn join_specs(fields : Array[String]) -> String {
  let out = StringBuilder()
  for i, field in fields {
    if i > 0 {
      out.write_string(", ")
    }
    out.write_string(field)
  }
  out.to_string()
}

///|
/// Structural descriptor of an ItemDefinition, used for `instance of` checks.
fn definition_descriptor(
  model : Model,
  node : @xml.Node,
  depth : Int32,
) -> String {
  if depth > 32 {
    return "Any"
  }
  let components = node.all("itemComponent")
  let base = if !components.is_empty() {
    let fields : Array[String] = []
    for component in components {
      fields.push(
        component.attr("name") +
        ": " +
        type_descriptor(model, item_type_name(component), depth + 1),
      )
    }
    "context<" + join_specs(fields) + ">"
  } else {
    type_descriptor(model, item_type_name(node), depth + 1)
  }
  if node.attr("isCollection") == "true" {
    "list<" + base + ">"
  } else {
    base
  }
}

///|
pub fn type_descriptor(
  model : Model,
  type_name : String,
  depth : Int32,
) -> String {
  if depth > 32 {
    return "Any"
  }
  let name = type_name.trim().to_owned()
  if name == "" || name == "Any" || name == "any" {
    return "any"
  }
  for definition in model.root.all("itemDefinition") {
    if definition.attr("name") == name {
      return definition_descriptor(model, definition, depth + 1)
    }
  }
  name
}

///|
/// Registry of named ItemDefinitions exposed to FEEL as `instance of` types.
pub fn type_registry(model : Model) -> Map[String, @types.Value] {
  let out : Map[String, @types.Value] = Map([])
  for definition in model.root.all("itemDefinition") {
    out[definition.attr("name")] = Text(
      definition_descriptor(model, definition, 0),
    )
  }
  out
}

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
  if value is Null {
    return
  }
  match type_name {
    "" | "Any" | "any" => return
    "number" => if value is Number(_) { return }
    "string" => if value is Text(_) { return }
    "boolean" => if value is Boolean(_) { return }
    "date" => if value is Date(_) { return }
    "time" => if value is Time(_) { return }
    "date and time" | "dateTime" => if value is DateTime(_) { return }
    "days and time duration" | "dayTimeDuration" =>
      if value is DaysSeconds(_) {
        return
      }
    "years and months duration" | "yearMonthDuration" =>
      if value is YearsMonths(_) {
        return
      }
    "duration" =>
      if value is DaysSeconds(_) || value is YearsMonths(_) {
        return
      }
    "list" => if value is List(_) { return }
    "context" => if value is Context(_) { return }
    "range" => if value is Range(_) { return }
    "function" => if value is Function(_) { return }
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
