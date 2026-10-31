///|
pub struct Model {
  root : @xml.Node
  decisions : Map[String, @xml.Node]
  ids : Map[String, String]
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
  let ids = Map([])
  for node in root.children {
    if node.uri != root.uri {
      continue
    }
    match node.name {
      "decision" | "inputData" => {
        let name = node.attr("name")
        let id = node.attr("id")
        if name == "" || id == "" {
          raise @types.fail("E_DMN_ID", "missing name or id")
        }
        if ids.contains(id) || ids.values().any(x => x == name) {
          raise @types.fail("E_DUPLICATE", "duplicate DMN id or name")
        }
        ids[id] = name
        if node.name == "decision" {
          decisions[name] = node
        }
      }
      "itemDefinition"
      | "businessKnowledgeModel"
      | "decisionService"
      | "import" =>
        raise @types.Failure(
          "E_DMN_UNSUPPORTED",
          node.line,
          node.column,
          "unsupported model element: " + node.name,
        )
      "DMNDI" | "description" | "extensionElements" => ()
      _ =>
        raise @types.Failure(
          "E_DMN_UNSUPPORTED",
          node.line,
          node.column,
          "unknown model element: " + node.name,
        )
    }
  }
  { root, decisions, ids, }
}

///|
pub fn evaluate_decision(
  model : Model,
  name : String,
  inputs : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
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
        ctx[dep] = evaluate_named(model, dep, inputs, cache, visiting)
      } else if reference.name == "requiredInput" {
        if !inputs.contains(dep) {
          raise @types.fail("E_INPUT_MISSING", "missing input: " + dep)
        }
      } else {
        raise @types.fail("E_DMN_UNSUPPORTED", "unknown requirement")
      }
    }
  }
  if !decision.all("knowledgeRequirement").is_empty() {
    raise @types.fail("E_DMN_UNSUPPORTED", "knowledgeRequirement")
  }
  let value = boxed(expression(decision), ctx)
  ignore(visiting.pop())
  cache[name] = value
  value
}

///|
pub fn expression(node : @xml.Node) -> @xml.Node raise @types.EngineError {
  let expressions = node.children.filter(n => {
    n.uri == node.uri &&
    [
      "literalExpression", "decisionTable", "context", "invocation", "list", "relation",
      "functionDefinition", "conditional", "filter", "for", "some", "every",
    ].contains(n.name)
  })
  if expressions.length() != 1 {
    raise @types.Failure(
      "E_DMN_EXPRESSION",
      node.line,
      node.column,
      "expected exactly one boxed expression",
    )
  }
  expressions[0]
}

///|
pub fn boxed(
  node : @xml.Node,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  match node.name {
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
    _ =>
      raise @types.Failure(
        "E_DMN_UNSUPPORTED",
        node.line,
        node.column,
        "unsupported expression: " + node.name,
      )
  }
}
