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
fn type_descriptor(model : Model, type_name : String, depth : Int32) -> String {
  if depth > 32 {
    return "Any"
  }
  let name = type_name.trim().to_owned()
  if imported_type(model, name) is Some((child, rest)) {
    return type_descriptor(child, rest, depth + 1)
  }
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
fn type_registry(model : Model) -> Map[String, @types.Value] {
  let out : Map[String, @types.Value] = Map([])
  for definition in model.root.all("itemDefinition") {
    out[definition.attr("name")] = Text(
      definition_descriptor(model, definition, 0),
    )
  }
  for (qualifier, child) in model.imports {
    for key, value in type_registry(child) {
      out[if qualifier == "" { key } else { qualifier + "." + key }] = value
    }
  }
  out
}

///|
/// Validate supported primitive, collection, qualifier and structured ItemDefinitions.
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
  if imported_type(model, type_name) is Some((child, rest)) {
    validate_type(child, rest, value, depth + 1)
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

///|
/// Apply FEEL singleton adaptation before checking the declared type.
fn coerce_type(
  model : Model,
  name : String,
  value : @types.Value,
  depth : Int32,
) -> @types.Value raise @types.EngineError {
  if depth > 32 {
    raise @types.fail("E_TYPE_CYCLE", "recursive ItemDefinition")
  }
  if value is Null || name == "" || name == "Any" || name == "any" {
    return value
  }
  if imported_type(model, name) is Some((child, rest)) {
    return coerce_type(child, rest, value, depth + 1)
  }
  for definition in model.root.all("itemDefinition") {
    if definition.attr("name") == name {
      return coerce_definition(model, definition, value, depth + 1, true)
    }
  }
  let value = if name != "list" {
    match value {
      List([one]) => one
      _ => value
    }
  } else {
    value
  }
  let value = if (name == "date and time" || name == "dateTime") &&
    value is Date(d) {
    @types.DateTime({
      date: d,
      time: @types.make_time(0, 0, 0, 0, @types.Fixed(0)),
    })
  } else {
    value
  }
  validate_type(model, name, value, depth)
  value
}

///|
fn coerce_definition(
  model : Model,
  node : @xml.Node,
  value : @types.Value,
  depth : Int32,
  collection : Bool,
) -> @types.Value raise @types.EngineError {
  if depth > 32 {
    raise @types.fail("E_TYPE_CYCLE", "recursive ItemDefinition")
  }
  if value is Null {
    return value
  }
  if collection && node.attr("isCollection") == "true" {
    let xs = match value {
      List(xs) => xs
      _ => [value]
    }
    return List(
      xs.map(x => coerce_definition(model, node, x, depth + 1, false)),
    )
  }
  if node.child("functionItem") is Some(item) {
    if value is Function(f) {
      return Function({
        name: f.name,
        params: f.params,
        callback: args => {
          coerce_type(
            model,
            item.attr("outputTypeRef"),
            (f.callback)(args),
            depth + 1,
          )
        },
      })
    }
    raise @types.fail("E_TYPE", "expected function")
  }
  let components = node.all("itemComponent")
  let value = if !components.is_empty() {
    match value {
      List([one]) => one
      _ => value
    }
  } else {
    value
  }
  let result = if components.is_empty() {
    coerce_type(model, item_type_name(node), value, depth + 1)
  } else {
    let ctx = match value {
      Context(c) => c.copy()
      _ => raise @types.fail("E_TYPE", "expected context")
    }
    for component in components {
      let key = component.attr("name")
      ctx[key] = coerce_definition(
        model,
        component,
        match ctx.get(key) {
          Some(v) => v
          None => raise @types.fail("E_TYPE", "missing field: " + key)
        },
        depth + 1,
        true,
      )
    }
    @types.Context(ctx)
  }
  if node.child("allowedValues") is Some(allowed) {
    if !@eval.unary_test(allowed.content("text"), result, Map([])) {
      raise @types.fail(
        "E_ALLOWED_VALUES", "ItemDefinition allowedValues violation",
      )
    }
  }
  result
}

///|
fn coerce_variable(
  model : Model,
  node : @xml.Node,
  value : @types.Value,
) -> @types.Value raise @types.EngineError {
  match node.child("variable") {
    Some(v) => coerce_type(model, v.attr("typeRef"), value, 0)
    None => value
  }
}

///|
/// Decode exact JSON input and convert declared temporal fields recursively.
/// Conversion is confined to this JSON boundary, not FEEL string coercion.
pub fn json_inputs(
  model : Model,
  json : String,
) -> Map[String, @types.Value] raise @types.EngineError {
  decode_inputs(model, @types.json_context(json))
}

///|
fn decode_inputs(
  model : Model,
  out : Map[String, @types.Value],
) -> Map[String, @types.Value] raise @types.EngineError {
  for (qualifier, child) in model.imports {
    if qualifier == "" {
      ignore(decode_inputs(child, out))
    } else if out.get(qualifier) is Some(Context(fields)) {
      out[qualifier] = Context(decode_inputs(child, fields.copy()))
    }
  }
  for node in model.root.children {
    if node.uri != model.root.uri ||
      (node.name != "inputData" && node.name != "decision") {
      continue
    }
    let name = node.attr("name")
    if out.get(name) is Some(value) && node.child("variable") is Some(variable) {
      out[name] = decode_declared(model, variable, value, 0, true)
    }
  }
  out
}

///|
fn decode_declared(
  model : Model,
  node : @xml.Node,
  value : @types.Value,
  depth : Int32,
  collection : Bool,
) -> @types.Value raise @types.EngineError {
  if depth > 32 {
    raise @types.fail("E_TYPE_CYCLE", "recursive JSON ItemDefinition")
  }
  if value is Null {
    return value
  }
  if collection && node.attr("isCollection") == "true" {
    let items = match value {
      List(xs) => xs
      _ => [value]
    }
    return List(
      items.map(x => decode_declared(model, node, x, depth + 1, false)),
    )
  }
  let fields = node.all("itemComponent")
  if !fields.is_empty() {
    let values = match value {
      Context(c) => c.copy()
      _ => raise @types.fail("E_TYPE", "JSON field must be an object")
    }
    for field in fields {
      let key = field.attr("name")
      if values.get(key) is Some(v) {
        values[key] = decode_declared(model, field, v, depth + 1, true)
      }
    }
    return Context(values)
  }
  let name = item_type_name(node)
  if imported_type(model, name) is Some((child, rest)) {
    for definition in child.root.all("itemDefinition") {
      if definition.attr("name") == rest {
        return decode_declared(child, definition, value, depth + 1, true)
      }
    }
  }
  for definition in model.root.all("itemDefinition") {
    if definition.attr("name") == name {
      return decode_declared(model, definition, value, depth + 1, true)
    }
  }
  if value is List(items) {
    return List(
      items.map(x => decode_declared(model, node, x, depth + 1, false)),
    )
  }
  if value is Text(text) {
    match name {
      "date" => return Date(@types.parse_date(text))
      "time" => return Time(@types.parse_time(text))
      "dateTime" | "date and time" =>
        return DateTime(@types.parse_datetime(text))
      "dayTimeDuration"
      | "days and time duration"
      | "yearMonthDuration"
      | "years and months duration"
      | "duration" => {
        let (days, months) = @types.parse_duration(text)
        let ym = text.contains("Y") ||
          text.split("T").to_array()[0].contains("M")
        if name == "dayTimeDuration" || name == "days and time duration" {
          if ym {
            raise @types.fail("E_TYPE", "expected days and time duration")
          }
          return DaysSeconds(days)
        }
        if name == "yearMonthDuration" || name == "years and months duration" {
          if !ym {
            raise @types.fail("E_TYPE", "expected years and months duration")
          }
          return YearsMonths(months)
        }
        return if ym { YearsMonths(months) } else { DaysSeconds(days) }
      }
      _ => ()
    }
  }
  value
}
