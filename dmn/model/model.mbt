///|
pub struct Model {
  root : @xml.Node
  decisions : Map[String, @xml.Node]
  bkms : Map[String, @xml.Node]
  services : Map[String, @xml.Node]
  ids : Map[String, String]
}

///|
fn is_expression_name(name : String) -> Bool {
  [
    "literalExpression", "decisionTable", "context", "invocation", "list", "relation",
    "functionDefinition", "conditional", "filter", "for", "some", "every",
  ].contains(name)
}

///|
fn expression_child(node : @xml.Node) -> @xml.Node raise @types.EngineError {
  for child in node.children {
    if child.uri == node.uri && is_expression_name(child.name) {
      return child
    }
  }
  raise @types.Failure(
    "E_DMN_EXPRESSION",
    node.line,
    node.column,
    "expected a boxed expression inside " + node.name,
  )
}

///|
pub fn parse_model(source : String) -> Model raise @types.EngineError {
  let root = @xml.parse(source)
  if root.name != "definitions" ||
    ![
      "https://www.omg.org/spec/DMN/20191111/MODEL/", "https://www.omg.org/spec/DMN/20211108/MODEL/",
      "https://www.omg.org/spec/DMN/20230324/MODEL/",
    ].contains(root.uri) {
    raise @types.Failure(
      "E_DMN_NAMESPACE",
      root.line,
      root.column,
      "expected DMN 1.3/1.4/1.5 definitions",
    )
  }
  let decisions = Map([])
  let bkms = Map([])
  let services = Map([])
  let ids = Map([])
  for node in root.children {
    if node.uri != root.uri {
      continue
    }
    match node.name {
      "decision" | "inputData" | "businessKnowledgeModel" | "decisionService" => {
        let declared = node.attr("name")
        let id = node.attr("id")
        if declared == "" && id == "" {
          raise @types.fail("E_DMN_ID", "missing name or id")
        }
        let name = if declared == "" { id } else { declared }
        if ids.contains(id) || ids.values().any(x => x == name) {
          raise @types.fail("E_DUPLICATE", "duplicate DMN id or name")
        }
        if id != "" {
          ids[id] = name
        }
        if node.name == "decision" {
          decisions[name] = node
        } else if node.name == "businessKnowledgeModel" {
          bkms[name] = node
        } else if node.name == "decisionService" {
          services[name] = node
        }
      }
      "itemDefinition"
      | "import"
      | "knowledgeSource"
      | "DMNDI"
      | "description"
      | "extensionElements" => ()
      _ =>
        raise @types.Failure(
          "E_DMN_UNSUPPORTED",
          node.line,
          node.column,
          "unknown model element: " + node.name,
        )
    }
  }
  { root, decisions, bkms, services, ids, }
}

///|
pub fn evaluate_decision(
  model : Model,
  name : String,
  inputs : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  for node in model.root.all("inputData") {
    if inputs.get(node.attr("name")) is Some(value) {
      validate_variable(model, node, value)
    }
  }
  let cache = Map([])
  let visiting = []
  evaluate_named(model, name, inputs, cache, visiting)
}

///|
fn evaluate_named(
  model : Model,
  name : String,
  inputs : Map[String, @types.Value],
  cache : Map[String, @types.Value],
  visiting : Array[String],
) -> @types.Value raise @types.EngineError {
  if cache.get(name) is Some(value) {
    return value
  }
  if visiting.contains(name) {
    raise @types.fail("E_DMN_CYCLE", "cyclic dependency: " + name)
  }
  if visiting.length() > 128 {
    raise @types.fail("E_LIMIT", "dependency depth")
  }
  let decision = match model.decisions.get(name) {
    Some(d) => d
    None => raise @types.fail("E_DECISION", "unknown decision: " + name)
  }
  visiting.push(name)
  let ctx = inputs.copy()
  if !ctx.contains("$types") {
    ctx["$types"] = Context(type_registry(model))
  }
  for req in decision.all("informationRequirement") {
    for reference in req.children {
      let href = reference.attr("href")
      if !href.has_prefix("#") {
        raise @types.fail("E_IMPORT_UNSUPPORTED", "external reference: " + href)
      }
      let id = href.strip_prefix("#").unwrap().to_owned()
      let dep = match model.ids.get(id) {
        Some(d) => d
        None => raise @types.fail("E_REFERENCE", "unknown reference: " + href)
      }
      if reference.name == "requiredDecision" {
        if inputs.get(dep) is Some(value) {
          let node = match model.decisions.get(dep) {
            Some(n) => n
            None => raise @types.fail("E_REFERENCE", "unknown decision: " + dep)
          }
          validate_variable(model, node, value)
          ctx[dep] = value
        } else {
          ctx[dep] = evaluate_named(model, dep, inputs, cache, visiting)
        }
      } else if reference.name == "requiredInput" {
        if !inputs.contains(dep) {
          raise @types.fail("E_INPUT_MISSING", "missing input: " + dep)
        }
      } else {
        raise @types.fail("E_DMN_UNSUPPORTED", "unknown requirement")
      }
    }
  }
  for req in decision.all("knowledgeRequirement") {
    for reference in req.children {
      let href = reference.attr("href")
      if !href.has_prefix("#") {
        raise @types.fail("E_IMPORT_UNSUPPORTED", "external reference: " + href)
      }
      let id = href.strip_prefix("#").unwrap().to_owned()
      let dep = match model.ids.get(id) {
        Some(d) => d
        None => raise @types.fail("E_REFERENCE", "unknown reference: " + href)
      }
      if model.bkms.get(dep) is Some(bkm) {
        ctx[dep] = bkm_function(model, bkm, ctx, 0)
      } else if model.services.get(dep) is Some(service) {
        ctx[dep] = service_function(model, service, ctx)
      } else {
        raise @types.fail("E_REFERENCE", "unknown knowledge: " + href)
      }
    }
  }
  let value = boxed(expression(decision), ctx)
  validate_variable(model, decision, value)
  ignore(visiting.pop())
  cache[name] = value
  value
}

///|
pub fn expression(node : @xml.Node) -> @xml.Node raise @types.EngineError {
  expression_child(node)
}

///|
fn bkm_function(
  model : Model,
  node : @xml.Node,
  outer : Map[String, @types.Value],
  depth : Int32,
) -> @types.Value raise @types.EngineError {
  if depth > 32 {
    raise @types.fail("E_LIMIT", "recursive BKM definitions")
  }
  let logic = match node.child("encapsulatedLogic") {
    Some(n) => n
    None => raise @types.fail("E_DMN_BKM", "missing encapsulatedLogic")
  }
  let params = logic.all("formalParameter").map(p => p.attr("name"))
  let body = expression_child(logic)
  let captured = outer.copy()
  for req in node.all("knowledgeRequirement") {
    for reference in req.children {
      let href = reference.attr("href")
      if !href.has_prefix("#") {
        raise @types.fail("E_IMPORT_UNSUPPORTED", "external reference: " + href)
      }
      let id = href.strip_prefix("#").unwrap().to_owned()
      let dep = match model.ids.get(id) {
        Some(d) => d
        None => raise @types.fail("E_REFERENCE", "unknown reference: " + href)
      }
      if model.bkms.get(dep) is Some(bkm) {
        captured[dep] = bkm_function(model, bkm, outer, depth + 1)
      } else if model.services.get(dep) is Some(service) {
        captured[dep] = service_function(model, service, outer)
      } else {
        raise @types.fail("E_REFERENCE", "unknown knowledge: " + href)
      }
    }
  }
  let name = node.attr("name")
  Function({
    name,
    params,
    callback: args => {
      if args.length() != params.length() {
        raise @types.fail(
          "E_ARITY",
          name + " expects " + params.length().to_string() + " arguments",
        )
      }
      let scope = captured.copy()
      for i, param in params {
        scope[param] = args[i]
      }
      boxed(body, scope)
    },
  })
}

///|
fn service_params(service : @xml.Node) -> Array[String] {
  let out = []
  for kind in ["inputDecision", "inputData"] {
    for node in service.all(kind) {
      out.push(node.attr("href"))
    }
  }
  out
}

///|
fn service_function(
  model : Model,
  service : @xml.Node,
  outer : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  let parameter_hrefs = service_params(service)
  let params = parameter_hrefs.map(href => href_id(model, href))
  let name = service.attr("name")
  let captured = outer.copy()
  Function({
    name,
    params,
    callback: args => {
      if args.length() != params.length() {
        raise @types.fail(
          "E_ARITY",
          name + " expects " + params.length().to_string() + " arguments",
        )
      }
      let inputs = captured.copy()
      for i, param in params {
        inputs[param] = args[i]
      }
      let outputs = evaluate_service_map(model, service, inputs)
      if outputs.length() == 1 {
        let mut value : @types.Value = Null
        for _, v in outputs {
          value = v
        }
        value
      } else {
        @types.Context(outputs)
      }
    },
  })
}

///|
fn href_id(model : Model, href : String) -> String raise @types.EngineError {
  if !href.has_prefix("#") {
    raise @types.fail("E_IMPORT_UNSUPPORTED", "external reference: " + href)
  }
  let id = href.strip_prefix("#").unwrap().to_owned()
  match model.ids.get(id) {
    Some(name) => name
    None => raise @types.fail("E_REFERENCE", "unknown reference: " + href)
  }
}

///|
fn evaluate_service_map(
  model : Model,
  service : @xml.Node,
  inputs : Map[String, @types.Value],
) -> Map[String, @types.Value] raise @types.EngineError {
  for kind in ["inputDecision", "inputData"] {
    for node in service.all(kind) {
      let name = href_id(model, node.attr("href"))
      if !inputs.contains(name) {
        raise @types.fail("E_INPUT_MISSING", "missing service input: " + name)
      }
      if kind == "inputData" {
        let mut found : @xml.Node? = None
        for data in model.root.all("inputData") {
          if data.attr("name") == name {
            found = Some(data)
          }
        }
        match found {
          Some(data) => validate_variable(model, data, inputs[name])
          None =>
            raise @types.fail("E_REFERENCE", "unknown input data: " + name)
        }
      } else {
        match model.decisions.get(name) {
          Some(decision) => validate_variable(model, decision, inputs[name])
          None => raise @types.fail("E_REFERENCE", "unknown decision: " + name)
        }
      }
    }
  }
  let cache = Map([])
  let visiting = []
  let out = Map([])
  for node in service.all("outputDecision") {
    let name = href_id(model, node.attr("href"))
    out[name] = evaluate_named(model, name, inputs, cache, visiting)
  }
  out
}

///|
/// Evaluate a business knowledge model directly for a TCK `type="bkm"` case.
pub fn evaluate_bkm(
  model : Model,
  name : String,
  arguments : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  let node = match model.bkms.get(name) {
    Some(n) => n
    None =>
      raise @types.fail(
        "E_DMN_BKM",
        "unknown business knowledge model: " + name,
      )
  }
  let outer : Map[String, @types.Value] = Map([])
  outer["$types"] = Context(type_registry(model))
  let value = bkm_function(model, node, outer, 0)
  match value {
    Function(f) => {
      let args = []
      for param in f.params {
        match arguments.get(param) {
          Some(v) => args.push(v)
          None =>
            raise @types.fail(
              "E_INPUT_MISSING",
              "missing BK argument: " + param,
            )
        }
      }
      (f.callback)(args)
    }
    _ => value
  }
}

///|
/// Evaluate a decision service and return its output decisions by name.
pub fn evaluate_service(
  model : Model,
  name : String,
  inputs : Map[String, @types.Value],
) -> Map[String, @types.Value] raise @types.EngineError {
  let service = match model.services.get(name) {
    Some(n) => n
    None =>
      raise @types.fail("E_DMN_SERVICE", "unknown decision service: " + name)
  }
  evaluate_service_map(model, service, inputs)
}

///|
pub fn boxed(
  node : @xml.Node,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  match node.name {
    "decisionTable" => table(node, ctx)
    "literalExpression" => {
      let language = node.attr("expressionLanguage")
      if language != "" && !language.contains("FEEL") {
        raise @types.fail("E_LANGUAGE", "non-FEEL expression language")
      }
      @eval.feel_eval(node.content("text"), ctx~)
    }
    "list" =>
      List(node.children.filter(n => n.uri == node.uri).map(n => boxed(n, ctx)))
    "context" => {
      let scope = ctx.copy()
      let out = Map([])
      let entries = node.all("contextEntry")
      for i, entry in entries {
        let value = boxed(expression(entry), scope)
        match entry.child("variable") {
          Some(v) => {
            let name = v.attr("name")
            scope[name] = value
            out[name] = value
          }
          None => {
            if i != entries.length() - 1 {
              raise @types.fail("E_DMN_CONTEXT", "unnamed entry must be last")
            }
            return value
          }
        }
      }
      Context(out)
    }
    "invocation" => {
      let callee_node = expression_child(node)
      let callee = boxed(callee_node, ctx)
      let args : Array[(String?, @types.Value)] = []
      for binding in node.all("binding") {
        let parameter = match binding.child("parameter") {
          Some(p) => p.attr("name")
          None =>
            raise @types.fail("E_DMN_INVOCATION", "missing binding parameter")
        }
        args.push((Some(parameter), boxed(expression_child(binding), ctx)))
      }
      match callee {
        Function(f) => @eval.call_function(f, args)
        _ =>
          raise @types.fail(
            "E_DMN_INVOCATION", "invocation target is not a function",
          )
      }
    }
    "relation" => {
      let columns = node.all("column").map(c => c.attr("name"))
      let rows = []
      for row in node.all("row") {
        let values = row.children.filter(n => {
          n.uri == node.uri && is_expression_name(n.name)
        })
        if values.length() != columns.length() {
          raise @types.fail("E_DMN_RELATION", "relation row length mismatch")
        }
        let record = Map([])
        for i, value in values {
          record[columns[i]] = boxed(value, ctx)
        }
        rows.push(@types.Context(record))
      }
      List(rows)
    }
    "functionDefinition" => {
      let params = node.all("formalParameter").map(p => p.attr("name"))
      let body = expression_child(node)
      let captured = ctx.copy()
      Function({
        name: "function",
        params,
        callback: args => {
          if args.length() != params.length() {
            raise @types.fail(
              "E_ARITY",
              "function expects " + params.length().to_string() + " arguments",
            )
          }
          let scope = captured.copy()
          for i, param in params {
            scope[param] = args[i]
          }
          boxed(body, scope)
        },
      })
    }
    "conditional" => {
      let condition = boxed(expression_child(node.child("if").unwrap()), ctx)
      match condition {
        Boolean(true) =>
          boxed(expression_child(node.child("then").unwrap()), ctx)
        Boolean(false) =>
          boxed(expression_child(node.child("else").unwrap()), ctx)
        Null => Null
        _ => raise @types.fail("E_DMN_CONDITIONAL", "condition is not boolean")
      }
    }
    "filter" => {
      let expressions = node.children.filter(n => {
        n.uri == node.uri && is_expression_name(n.name)
      })
      if expressions.length() != 2 {
        raise @types.fail("E_DMN_FILTER", "filter needs a list and a predicate")
      }
      let target = boxed(expressions[0], ctx)
      let items = match target {
        List(xs) => xs
        Null => return Null
        _ => [target]
      }
      filter_items(items, expressions[1], ctx)
    }
    "for" | "some" | "every" => {
      let kind = node.name
      let bindings = node.all("binding")
      let mut in_node : @xml.Node? = None
      let mut body : @xml.Node? = None
      for child in node.children {
        if child.uri != node.uri {
          continue
        }
        if child.name == "in" {
          in_node = Some(child)
        } else if child.name == "return" || child.name == "satisfies" {
          body = Some(child)
        } else if is_expression_name(child.name) {
          body = Some(child)
        }
      }
      if in_node is Some(domain) {
        let variable = node.attr("iteratorVariable")
        if variable == "" {
          raise @types.fail("E_DMN_ITERATOR", "missing iterator variable")
        }
        let body = match body {
          Some(n) => n
          None => raise @types.fail("E_DMN_ITERATOR", "missing iterator body")
        }
        let source = boxed(expression_child(domain), ctx)
        let items = match source {
          List(xs) => xs
          _ =>
            raise @types.fail(
              "E_DMN_ITERATOR", "boxed iterator requires a list",
            )
        }
        let body_expr = expression_child(body)
        return iterator_values(kind, variable, items, body_expr, ctx)
      }
      let body = match body {
        Some(n) => n
        None => raise @types.fail("E_DMN_ITERATOR", "missing iterator body")
      }
      iterator(kind, bindings, body, ctx)
    }
    _ =>
      raise @types.Failure(
        "E_DMN_UNSUPPORTED",
        node.line,
        node.column,
        "unsupported expression: " + node.name,
      )
  }
}

///|
fn filter_items(
  items : Array[@types.Value],
  predicate : @xml.Node,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  let first = if items.is_empty() {
    boxed(predicate, ctx)
  } else {
    boxed(predicate, scope_with(ctx, "item", items[0]))
  }
  match first {
    Number(n) => {
      if !n.is_integer() {
        raise @types.fail("E_DMN_FILTER", "filter index must be an integer")
      }
      let at = n.to_int()
      if at < 1 || at > items.length() {
        Null
      } else {
        items[at - 1]
      }
    }
    _ => {
      let out = []
      for item in items {
        let keep = match boxed(predicate, scope_with(ctx, "item", item)) {
          Boolean(b) => b
          Null => false
          _ =>
            raise @types.fail("E_DMN_FILTER", "filter predicate is not boolean")
        }
        if keep {
          out.push(item)
        }
      }
      List(out)
    }
  }
}

///|
fn scope_with(
  ctx : Map[String, @types.Value],
  name : String,
  value : @types.Value,
) -> Map[String, @types.Value] {
  let out = ctx.copy()
  out[name] = value
  out
}

///|
fn iterator_values(
  kind : String,
  variable : String,
  items : Array[@types.Value],
  body : @xml.Node,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  if kind == "for" {
    let out = []
    for item in items {
      out.push(boxed(body, scope_with(ctx, variable, item)))
    }
    return List(out)
  }
  let some = kind == "some"
  let mut has_null = false
  for item in items {
    match boxed(body, scope_with(ctx, variable, item)) {
      Boolean(false) => if !some { return Boolean(false) }
      Boolean(true) => if some { return Boolean(true) }
      Null => has_null = true
      _ => raise @types.fail("E_DMN_ITERATOR", "iterator body is not boolean")
    }
  }
  if has_null {
    Null
  } else if some {
    Boolean(false)
  } else {
    Boolean(true)
  }
}

///|
fn iterator(
  kind : String,
  bindings : Array[@xml.Node],
  body : @xml.Node,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  let envs = iterator_envs(bindings, 0, ctx, 0)
  if kind == "for" {
    return List(envs.map(env => boxed(body, env)))
  }
  let some = kind == "some"
  let mut has_null = false
  for env in envs {
    match boxed(body, env) {
      Boolean(false) => if !some { return Boolean(false) }
      Boolean(true) => if some { return Boolean(true) }
      Null => has_null = true
      _ => raise @types.fail("E_DMN_ITERATOR", "iterator body is not boolean")
    }
  }
  if has_null {
    Null
  } else if some {
    Boolean(false)
  } else {
    Boolean(true)
  }
}

///|
fn iterator_envs(
  bindings : Array[@xml.Node],
  index : Int32,
  scope : Map[String, @types.Value],
  count : Int32,
) -> Array[Map[String, @types.Value]] raise @types.EngineError {
  if count > 100000 {
    raise @types.fail("E_LIMIT", "iterator produces too many values")
  }
  if index >= bindings.length() {
    return [scope.copy()]
  }
  let binding = bindings[index]
  let name = match binding.child("variable") {
    Some(v) => v.attr("name")
    None => raise @types.fail("E_DMN_ITERATOR", "missing iterator variable")
  }
  let value = boxed(expression_child(binding), scope)
  let items = match value {
    List(xs) => xs
    _ => [value]
  }
  let out = []
  for item in items {
    let inner = scope.copy()
    inner[name] = item
    out.append(iterator_envs(bindings, index + 1, inner, count + out.length()))
  }
  out
}
