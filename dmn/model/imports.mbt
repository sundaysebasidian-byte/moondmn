///|
fn import_directory(path : String) -> String {
  let parts = path.split("/").to_array()
  ignore(parts.pop())
  if parts.is_empty() {
    ""
  } else {
    parts.join("/") + "/"
  }
}

///|
fn collect_import_inputs(
  model : Model,
  inputs : Map[String, @types.Value],
  shared : Map[String, @types.Value],
) -> Unit {
  let ns = model.root.attr("namespace")
  let merged = match shared.get(ns) {
    Some(Context(c)) => c
    _ => Map([])
  }
  for k, v in inputs {
    if k != "$imports" {
      merged[k] = v
    }
  }
  shared[ns] = Context(merged)
  for (qualifier, child) in model.imports {
    let scope = if qualifier == "" {
      inputs
    } else {
      match inputs.get(qualifier) {
        Some(Context(c)) => c
        _ => Map([])
      }
    }
    collect_import_inputs(child, scope, shared)
  }
}

///|
fn imported_inputs(
  child : Model,
  qualifier : String,
  inputs : Map[String, @types.Value],
) -> Map[String, @types.Value] {
  let scope = match inputs.get("$imports") {
    Some(Context(shared)) =>
      match shared.get(child.root.attr("namespace")) {
        Some(Context(c)) => c.copy()
        _ => Map([])
      }
    _ =>
      if qualifier == "" {
        inputs.copy()
      } else {
        match inputs.get(qualifier) {
          Some(Context(c)) => c.copy()
          _ => Map([])
        }
      }
  }
  for key in ["$imports", "$external", "now", "today"] {
    if inputs.get(key) is Some(v) {
      scope[key] = v
    }
  }
  scope
}

///|
fn bind_import(
  ctx : Map[String, @types.Value],
  qualifier : String,
  name : String,
  value : @types.Value,
) -> Unit {
  if qualifier == "" {
    ctx[name] = value
  } else {
    let fields = match ctx.get(qualifier) {
      Some(Context(c)) => c.copy()
      _ => Map([])
    }
    fields[name] = value
    ctx[qualifier] = Context(fields)
  }
}

///|
fn import_scope(
  model : Model,
  inputs : Map[String, @types.Value],
  ctx : Map[String, @types.Value],
) -> Unit raise @types.EngineError {
  for (qualifier, child) in model.imports {
    let scope = imported_inputs(child, qualifier, inputs)
    for node in child.root.all("inputData") {
      let name = node.attr("name")
      if import_visible(model, qualifier, child, name) &&
        scope.get(name) is Some(v) {
        bind_import(ctx, qualifier, name, coerce_variable(child, node, v))
      }
    }
    // A direct import also exposes its imported input contexts.
    let nested = scope.copy()
    import_scope(child, scope, nested)
    for (nested_alias, _) in child.imports {
      if nested_alias != "" &&
        import_visible(model, qualifier, child, nested_alias) &&
        nested.get(nested_alias) is Some(v) {
        bind_import(ctx, qualifier, nested_alias, v)
      }
    }
  }
}

///|
fn imported_requirement(
  model : Model,
  reference : @xml.Node,
  inputs : Map[String, @types.Value],
  ctx : Map[String, @types.Value],
) -> Bool raise @types.EngineError {
  let href = reference.attr("href")
  for (qualifier, child) in model.imports {
    let prefix = child.root.attr("namespace") + "#"
    if !href.has_prefix(prefix) {
      continue
    }
    let name = href_id(child, href) catch {
      @types.Failure(code, _, _, message) =>
        raise @types.Failure(code, reference.line, reference.column, message)
    }
    if !import_visible(model, qualifier, child, name) {
      return true
    }
    let scope = imported_inputs(child, qualifier, inputs)
    let value = match reference.name {
      "requiredInput" =>
        match scope.get(name) {
          Some(v) => {
            let mut value = v
            for node in child.root.all("inputData") {
              if node.attr("name") == name {
                value = coerce_variable(child, node, v)
              }
            }
            value
          }
          None =>
            raise @types.Failure(
              "E_INPUT_MISSING",
              reference.line,
              reference.column,
              "missing imported input: " + name,
            )
        }
      "requiredDecision" =>
        match scope.get(name) {
          Some(v) => coerce_variable(child, child.decisions[name], v)
          None => evaluate_decision(child, name, scope)
        }
      "requiredKnowledge" =>
        if child.bkms.get(name) is Some(n) {
          bkm_function(child, n, scope, 0)
        } else if child.services.get(name) is Some(n) {
          service_function(child, n, scope)
        } else {
          raise @types.Failure(
            "E_REFERENCE",
            reference.line,
            reference.column,
            "unknown imported knowledge: " + href,
          )
        }
      _ =>
        raise @types.Failure(
          "E_REFERENCE",
          reference.line,
          reference.column,
          "unknown requirement: " + reference.name,
        )
    }
    bind_import(ctx, qualifier, name, value)
    return true
  }
  if !href.has_prefix("#") &&
    !href.has_prefix(model.root.attr("namespace") + "#") {
    raise @types.Failure(
      "E_REFERENCE",
      reference.line,
      reference.column,
      "unresolved namespace reference: " + href,
    )
  }
  false
}

///|
fn imported_type(model : Model, name : String) -> (Model, String)? {
  for (qualifier, child) in model.imports {
    if qualifier == "" {
      if import_visible(model, qualifier, child, name) &&
        child.root.all("itemDefinition").any(n => n.attr("name") == name) {
        return Some((child, name))
      }
    } else if name.strip_prefix(qualifier + ".") is Some(rest) {
      return Some((child, rest.to_owned()))
    }
  }
  None
}

///|
/// Bind a TCK/host input to its declaring namespace, or the root scope.
pub fn bind_input(
  inputs : Map[String, @types.Value],
  name : String,
  value : @types.Value,
  model_namespace~ : String = "",
) -> Unit {
  if model_namespace == "" {
    inputs[name] = value
    return
  }
  let shared = match inputs.get("$imports") {
    Some(Context(c)) => c
    _ => Map([])
  }
  let scope = match shared.get(model_namespace) {
    Some(Context(c)) => c
    _ => Map([])
  }
  scope[name] = value
  shared[model_namespace] = Context(scope)
  inputs["$imports"] = Context(shared)
}

///|
fn direct_exported_names(model : Model) -> Map[String, String] {
  let out = Map([])
  for node in model.root.children {
    if node.uri == model.root.uri &&
      [
        "decision", "inputData", "businessKnowledgeModel", "decisionService", "itemDefinition",
      ].contains(node.name) {
      let name = if node.attr("name") == "" {
        node.attr("id")
      } else {
        node.attr("name")
      }
      out[name] = model.root.attr("namespace")
    }
  }
  for (qualifier, child) in model.imports {
    if qualifier != "" {
      out[qualifier] = "alias:" + child.root.attr("namespace")
    }
  }
  out
}

///|
fn exported_names(model : Model) -> Map[String, String] {
  let out = direct_exported_names(model)
  for (qualifier, child) in model.imports {
    if qualifier == "" {
      for name, owner in direct_exported_names(child) {
        if !out.contains(name) {
          out[name] = owner
        }
      }
    }
  }
  out
}

///|
fn import_visible(
  model : Model,
  qualifier : String,
  child : Model,
  name : String,
) -> Bool {
  qualifier != "" ||
  (
    direct_exported_names(child).get(name) is Some(owner) &&
    exported_names(model).get(name) == Some(owner)
  )
}
