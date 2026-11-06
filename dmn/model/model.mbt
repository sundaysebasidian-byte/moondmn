///|
/// Parsed model indexes; treat as immutable during evaluation.
pub struct Model {
  root : @xml.Node
  decisions : Map[String, @xml.Node]
  bkms : Map[String, @xml.Node]
  services : Map[String, @xml.Node]
  ids : Map[String, String]
  imports : Array[(String, Model)]
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
/// Parse namespace-aware DMN XML and index its named elements.
pub fn parse_model(
  source : String,
  resolver~ : ((String, String) -> String raise @types.EngineError)? = None,
) -> Model raise @types.EngineError {
  load_model(source, resolver, [], "", None, "<root>")
}

///|
fn load_model(
  source : String,
  resolver : ((String, String) -> String raise @types.EngineError)?,
  stack : Array[String],
  base : String,
  expected_ns : String?,
  source_location : String,
) -> Model raise @types.EngineError {
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
  let model_ns = root.attr("namespace")
  if expected_ns is Some(ns) && model_ns != ns {
    raise @types.Failure(
      "E_IMPORT_NAMESPACE",
      root.line,
      root.column,
      "import namespace mismatch: " + ns,
    )
  }
  if stack.contains(model_ns) {
    raise @types.Failure(
      "E_IMPORT_CYCLE",
      root.line,
      root.column,
      "cyclic import: " + model_ns,
    )
  }
  if stack.length() >= 32 {
    raise @types.Failure(
      "E_IMPORT_DEPTH",
      root.line,
      root.column,
      "import depth exceeds 32",
    )
  }
  let next = stack.copy()
  next.push(model_ns)
  let imports : Array[(String, Model)] = []
  for node in root.all("import") {
    let qualifier = node.attr("name")
    if qualifier != "" && imports.any(i => i.0 == qualifier) {
      raise @types.Failure(
        "E_IMPORT_ALIAS",
        node.line,
        node.column,
        "duplicate import qualifier: " + qualifier,
      )
    }
    if node.attr("importType") != root.uri {
      raise @types.Failure(
        "E_IMPORT_TYPE",
        node.line,
        node.column,
        "unsupported importType: " + node.attr("importType"),
      )
    }
    let resolve = match resolver {
      Some(r) => r
      None =>
        raise @types.Failure(
          "E_IMPORT_NOT_FOUND",
          node.line,
          node.column,
          "import requires a resolver",
        )
    }
    let location = node.attr("locationURI")
    let path = if location == "" {
      base
    } else if location.has_prefix("/") || location.contains(":") {
      location
    } else {
      base + location
    }
    let imported = load_model(
      resolve(path, node.attr("namespace")),
      resolver,
      next,
      import_directory(path),
      Some(node.attr("namespace")),
      path,
    ) catch {
      @types.Failure("E_IMPORT_CYCLE", line, column, message) => {
        if message.has_prefix("cyclic import: ") {
          raise @types.Failure(
            "E_IMPORT_CYCLE",
            node.line,
            node.column,
            "import cycle in " +
            source_location +
            ":" +
            node.line.to_string() +
            ":" +
            node.column.to_string() +
            ": " +
            node.attr("namespace"),
          )
        }
        raise @types.Failure("E_IMPORT_CYCLE", line, column, message)
      }
      @types.Failure(code, _, _, message) =>
        raise @types.Failure(code, node.line, node.column, message)
    }
    imports.push((qualifier, imported))
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
  for (qualifier, _) in imports {
    if qualifier != "" &&
      root.children.any(n => {
        n.uri == root.uri &&
        [
          "decision", "inputData", "businessKnowledgeModel", "decisionService", "itemDefinition",
        ].contains(n.name) &&
        (
          n.attr("name") == qualifier ||
          (n.attr("name") == "" && n.attr("id") == qualifier)
        )
      }) {
      let node = root.all("import").filter(n => n.attr("name") == qualifier)[0]
      raise @types.Failure(
        "E_IMPORT_ALIAS",
        node.line,
        node.column,
        "import alias conflicts with local name: " + qualifier,
      )
    }
  }
  { root, decisions, bkms, services, ids, imports, }
}

///|
/// Evaluate a named decision against typed input values.
pub fn evaluate_decision(
  model : Model,
  name : String,
  inputs : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  let inputs = inputs.copy()
  {
    let shared = match inputs.get("$imports") {
      Some(Context(c)) => c.copy()
      _ => Map([])
    }
    collect_import_inputs(model, inputs, shared)
    inputs["$imports"] = Context(shared)
    if shared.get(model.root.attr("namespace")) is Some(Context(values)) {
      for key, value in values {
        if !inputs.contains(key) {
          inputs[key] = value
        }
      }
    }
  }
  for node in model.root.all("inputData") {
    let key = node.attr("name")
    if inputs.get(key) is Some(value) {
      inputs[key] = coerce_variable(model, node, value)
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
  import_scope(model, inputs, ctx)
  if !ctx.contains("$types") {
    ctx["$types"] = Context(type_registry(model))
  }
  for req in decision.all("informationRequirement") {
    for reference in req.children {
      let href = reference.attr("href")
      if imported_requirement(model, reference, inputs, ctx) {
        continue
      }
      let dep = href_id(model, href)
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
      if imported_requirement(model, reference, inputs, ctx) {
        continue
      }
      let dep = href_id(model, href)
      if model.bkms.get(dep) is Some(bkm) {
        ctx[dep] = bkm_function(model, bkm, ctx, 0)
      } else if model.services.get(dep) is Some(service) {
        ctx[dep] = service_function(model, service, ctx)
      } else {
        raise @types.fail("E_REFERENCE", "unknown knowledge: " + href)
      }
    }
  }
  let value = coerce_variable(
    model,
    decision,
    boxed(model, expression(decision), ctx),
  ) catch {
    @types.Failure("E_TYPE", _, _, _) => Null
    e => raise e
  }
  ignore(visiting.pop())
  cache[name] = value
  value
}

///|
fn expression(node : @xml.Node) -> @xml.Node raise @types.EngineError {
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
  captured["$types"] = Context(type_registry(model))
  import_scope(model, outer, captured)
  for req in node.all("knowledgeRequirement") {
    for reference in req.children {
      let href = reference.attr("href")
      if imported_requirement(model, reference, outer, captured) {
        continue
      }
      let dep = href_id(model, href)
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
        scope[param] = coerce_type(
          model,
          logic.all("formalParameter")[i].attr("typeRef"),
          args[i],
          0,
        )
      }
      match
        coerce_variable(
          model,
          node,
          @types.Function({
            name: "result",
            params: [],
            callback: _ => {
              if logic.attr("kind") == "Java" {
                java_boxed(model, body, scope, params.map(p => scope[p]))
              } else {
                boxed(model, body, scope)
              }
            },
          }),
        ) {
        Function(f) => (f.callback)([])
        _ => boxed(model, body, scope)
      }
    },
  })
}

///|
fn service_params(service : @xml.Node) -> Array[String] {
  let out = []
  for kind in ["inputData", "inputDecision"] {
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
      let outputs = evaluate_service(model, service.attr("name"), inputs)
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
  let href = if model.root.attr("namespace") != "" {
    href
    .strip_prefix(model.root.attr("namespace"))
    .unwrap_or(href[:])
    .to_owned()
  } else {
    href
  }
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
  for kind in ["inputData", "inputDecision"] {
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
          Some(data) =>
            inputs[name] = coerce_variable(model, data, inputs[name])
          None =>
            raise @types.fail("E_REFERENCE", "unknown input data: " + name)
        }
      } else {
        match model.decisions.get(name) {
          Some(decision) =>
            inputs[name] = coerce_variable(model, decision, inputs[name])
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
  import_scope(model, arguments, outer)
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
  let outputs = evaluate_service_map(model, service, inputs.copy())
  if outputs.length() == 1 {
    for key, value in outputs {
      let wrapped = coerce_variable(
        model,
        service,
        Function({ name: "result", params: [], callback: _ => value, }),
      )
      if wrapped is Function(f) {
        outputs[key] = (f.callback)([])
      }
    }
  }
  outputs
}

///|
fn boxed_raw(
  model : Model,
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
      List(
        node.children
        .filter(n => n.uri == node.uri)
        .map(n => boxed(model, n, ctx)),
      )
    "context" => {
      let scope = ctx.copy()
      let out = Map([])
      let entries = node.all("contextEntry")
      for i, entry in entries {
        let value = coerce_variable(
          model,
          entry,
          boxed(model, expression(entry), scope),
        )
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
      let callee = boxed(model, callee_node, ctx)
      let args : Array[(String?, @types.Value)] = []
      for binding in node.all("binding") {
        let parameter = match binding.child("parameter") {
          Some(p) => p.attr("name")
          None =>
            raise @types.fail("E_DMN_INVOCATION", "missing binding parameter")
        }
        args.push(
          (Some(parameter), boxed(model, expression_child(binding), ctx)),
        )
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
          record[columns[i]] = boxed(model, value, ctx)
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
            scope[param] = coerce_type(
              model,
              node.all("formalParameter")[i].attr("typeRef"),
              args[i],
              0,
            )
          }
          if node.attr("kind") == "Java" {
            java_boxed(model, body, scope, params.map(p => scope[p]))
          } else {
            boxed(model, body, scope)
          }
        },
      })
    }
    "conditional" => {
      let condition = expression_child(required_child(node, "if"))
      let yes = expression_child(required_child(node, "then"))
      let no = expression_child(required_child(node, "else"))
      match boxed(model, condition, ctx) {
        Boolean(true) => boxed(model, yes, ctx)
        Boolean(false) => boxed(model, no, ctx)
        _ => Null
      }
    }
    "filter" => {
      let expressions = if node.child("in") is Some(domain) &&
        node.child("match") is Some(predicate) {
        [expression_child(domain), expression_child(predicate)]
      } else {
        node.children.filter(n => {
          n.uri == node.uri && is_expression_name(n.name)
        })
      }
      if expressions.length() != 2 {
        raise @types.fail("E_DMN_FILTER", "filter needs a list and a predicate")
      }
      let target = boxed(model, expressions[0], ctx)
      let items = match target {
        List(xs) => xs
        Null => return Null
        _ => [target]
      }
      filter_items(model, items, expressions[1], ctx)
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
        let source = boxed(model, expression_child(domain), ctx)
        let items = match source {
          List(xs) => xs
          _ => [source]
        }
        let body_expr = expression_child(body)
        return iterator_values(model, kind, variable, items, body_expr, ctx)
      }
      let body = match body {
        Some(n) => n
        None => raise @types.fail("E_DMN_ITERATOR", "missing iterator body")
      }
      iterator(model, kind, bindings, body, ctx)
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
  model : Model,
  items : Array[@types.Value],
  predicate : @xml.Node,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  let first = if items.is_empty() {
    boxed(model, predicate, ctx)
  } else {
    boxed(model, predicate, scope_with(ctx, "item", items[0]))
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
        let keep = match
          boxed(model, predicate, scope_with(ctx, "item", item)) {
          Boolean(b) => b
          Null => false
          _ => return Null
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
  model : Model,
  kind : String,
  variable : String,
  items : Array[@types.Value],
  body : @xml.Node,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  if kind == "for" {
    let out = []
    for item in items {
      out.push(boxed(model, body, scope_with(ctx, variable, item)))
    }
    return List(out)
  }
  let some = kind == "some"
  let mut has_null = false
  for item in items {
    match boxed(model, body, scope_with(ctx, variable, item)) {
      Boolean(false) => if !some { return Boolean(false) }
      Boolean(true) => if some { return Boolean(true) }
      Null => has_null = true
      _ => return Null
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
  model : Model,
  kind : String,
  bindings : Array[@xml.Node],
  body : @xml.Node,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  let envs = iterator_envs(model, bindings, 0, ctx, 0)
  if kind == "for" {
    return List(envs.map(env => boxed(model, body, env)))
  }
  let some = kind == "some"
  let mut has_null = false
  for env in envs {
    match boxed(model, body, env) {
      Boolean(false) => if !some { return Boolean(false) }
      Boolean(true) => if some { return Boolean(true) }
      Null => has_null = true
      _ => return Null
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
  model : Model,
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
  let value = boxed(model, expression_child(binding), scope)
  let items = match value {
    List(xs) => xs
    _ => [value]
  }
  let out = []
  for item in items {
    let inner = scope.copy()
    inner[name] = item
    out.append(
      iterator_envs(model, bindings, index + 1, inner, count + out.length()),
    )
  }
  out
}

///|
fn required_child(
  node : @xml.Node,
  name : String,
) -> @xml.Node raise @types.EngineError {
  let children = node.all(name)
  if children.length() != 1 {
    raise @types.Failure(
      "E_DMN_SHAPE",
      node.line,
      node.column,
      "expected exactly one " + name + " in " + node.name,
    )
  }
  children[0]
}

///|
fn boxed(
  model : Model,
  node : @xml.Node,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  coerce_type(model, node.attr("typeRef"), boxed_raw(model, node, ctx), 0)
}
