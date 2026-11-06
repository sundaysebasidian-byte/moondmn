///|
let expression_names : Array[String] = [
  "literalExpression", "decisionTable", "context", "invocation", "list", "relation",
  "functionDefinition", "conditional", "filter", "for", "some", "every",
]

///|
fn strings_json(values : Array[String]) -> Json {
  Json::array(values.map(Json::string))
}

///|
fn expression_of(node : @xml.Node) -> @xml.Node? {
  for child in node.children {
    if child.uri == node.uri && expression_names.contains(child.name) {
      return Some(child)
    }
  }
  None
}

///|
fn declared_name(node : @xml.Node) -> String {
  if node.attr("name") != "" {
    node.attr("name")
  } else {
    node.attr("id")
  }
}

///|
fn type_ref(node : @xml.Node) -> String {
  let name = if node.attr("typeRef") != "" {
    node.attr("typeRef")
  } else {
    node.content("typeRef")
  }
  let trimmed = name.trim().to_owned()
  match trimmed.strip_prefix("feel:") {
    Some(rest) => rest.to_owned()
    None => trimmed
  }
}

///|
fn primitive_base(name : String) -> String? {
  match name {
    "number" | "string" | "boolean" | "date" | "time" => Some(name)
    "date and time" | "dateTime" => Some("dateTime")
    "days and time duration" | "dayTimeDuration" => Some("dayTimeDuration")
    "years and months duration" | "yearMonthDuration" =>
      Some("yearMonthDuration")
    "" | "Any" | "any" => Some("any")
    "context" | "list" | "range" | "function" => Some(name)
    _ => None
  }
}

///|
/// Allowed values as the form needs them: a closed list, a numeric range, or
/// the raw unary-test text when neither applies.
fn allowed_json(text : String) -> Json {
  let source = text.trim().to_owned()
  if source == "" {
    return Json::null()
  }
  let raw = obj([("kind", Json::string("text")), ("text", Json::string(source))])
  let parsed = @eval.feel_eval("[" + source + "]") catch { _ => return raw }
  let items = match parsed {
    List(items) => items
    _ => return raw
  }
  let values : Array[Json] = []
  for item in items {
    match item {
      @types.Text(_) | @types.Number(_) | @types.Boolean(_) =>
        values.push(item.json() catch { _ => return raw })
      @types.Range(range) =>
        match (range.start, range.end) {
          (Some(@types.Number(low)), Some(@types.Number(high))) if items.length() ==
            1 =>
            return obj([
              ("kind", Json::string("range")),
              ("min", @json.parse(low.text()) catch { _ => return raw }),
              ("max", @json.parse(high.text()) catch { _ => return raw }),
            ])
          _ => return raw
        }
      _ => return raw
    }
  }
  obj([("kind", Json::string("enum")), ("values", Json::array(values))])
}

///|
fn find_definition(model : @model.Model, name : String) -> @xml.Node? {
  for definition in model.root.all("itemDefinition") {
    if definition.attr("name") == name {
      return Some(definition)
    }
  }
  None
}

///|
/// Resolved shape of a type reference: `{name, base, collection, allowed?, fields?}`.
fn type_json(model : @model.Model, name : String, depth : Int32) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["name"] = Json::string(name)
  fields["collection"] = Json::boolean(false)
  if depth > 16 {
    fields["base"] = Json::string("any")
    return Json::object(fields)
  }
  match primitive_base(name) {
    Some(base) => {
      fields["base"] = Json::string(base)
      return Json::object(fields)
    }
    None => ()
  }
  match find_definition(model, name) {
    None => fields["base"] = Json::string("any")
    Some(definition) => {
      let components = definition.all("itemComponent")
      let allowed = match definition.child("allowedValues") {
        Some(node) => allowed_json(node.content("text"))
        None => Json::null()
      }
      if components.is_empty() {
        let inner = type_json(model, type_ref(definition), depth + 1)
        match inner {
          Object(m) =>
            for key, value in m {
              if key != "name" {
                fields[key] = value
              }
            }
          _ => ()
        }
      } else {
        fields["base"] = Json::string("context")
        fields["fields"] = Json::array(
          components.map(component => component_json(model, component, depth)),
        )
      }
      if allowed is Object(_) {
        fields["allowed"] = allowed
      }
      if definition.attr("isCollection") == "true" {
        fields["collection"] = Json::boolean(true)
      }
    }
  }
  Json::object(fields)
}

///|
fn component_json(
  model : @model.Model,
  component : @xml.Node,
  depth : Int32,
) -> Json {
  let shape = type_json(model, type_ref(component), depth + 1)
  let merged : Map[String, Json] = match shape {
    Object(m) => m
    _ => Map([])
  }
  merged["label"] = Json::string(component.attr("name"))
  if component.attr("isCollection") == "true" {
    merged["collection"] = Json::boolean(true)
  }
  if component.child("allowedValues") is Some(node) {
    merged["allowed"] = allowed_json(node.content("text"))
  }
  Json::object(merged)
}

///|
fn requirement_target(
  model : @model.Model,
  reference : @xml.Node,
) -> (String, Bool) {
  let href = reference.attr("href")
  match href.strip_prefix("#") {
    Some(id) =>
      match model.ids.get(id.to_owned()) {
        Some(name) => (name, true)
        None => (href, false)
      }
    None => (href, false)
  }
}

///|
fn table_json(table : @xml.Node) -> Json {
  let hit_policy = if table.attr("hitPolicy") == "" {
    "UNIQUE"
  } else {
    table.attr("hitPolicy")
  }
  let inputs = table
    .all("input")
    .map(input => {
      let expression = match input.child("inputExpression") {
        Some(n) => n.content("text")
        None => ""
      }
      let allowed = match input.child("inputValues") {
        Some(n) => n.content("text")
        None => ""
      }
      obj([
        ("label", Json::string(input.attr("label"))),
        ("expression", Json::string(expression)),
        ("allowed", Json::string(allowed)),
      ])
    })
  let outputs = table
    .all("output")
    .map(output => {
      let allowed = match output.child("outputValues") {
        Some(n) => n.content("text")
        None => ""
      }
      obj([
        ("name", Json::string(declared_name(output))),
        ("label", Json::string(output.attr("label"))),
        ("allowed", Json::string(allowed)),
      ])
    })
  let rules = table
    .all("rule")
    .map(rule => {
      obj([
        (
          "inputs",
          strings_json(rule.all("inputEntry").map(n => n.content("text"))),
        ),
        (
          "outputs",
          strings_json(rule.all("outputEntry").map(n => n.content("text"))),
        ),
        (
          "annotations",
          strings_json(rule.all("annotationEntry").map(n => n.content("text"))),
        ),
        ("line", int_json(rule.line)),
      ])
    })
  obj([
    ("hitPolicy", Json::string(hit_policy)),
    ("aggregation", Json::string(table.attr("aggregation"))),
    ("inputs", Json::array(inputs)),
    ("outputs", Json::array(outputs)),
    ("rules", Json::array(rules)),
  ])
}

///|
fn requirement_list(
  model : @model.Model,
  owner : @xml.Node,
  edges : Array[Json],
  target : String,
) -> Array[Json] {
  let out : Array[Json] = []
  for requirement in owner.all("informationRequirement") {
    for reference in requirement.children {
      let (name, resolved) = requirement_target(model, reference)
      let kind = if reference.name == "requiredInput" {
        "input"
      } else {
        "decision"
      }
      out.push(
        obj([
          ("name", Json::string(name)),
          ("kind", Json::string(kind)),
          ("resolved", Json::boolean(resolved)),
        ]),
      )
      edges.push(
        obj([
          ("from", Json::string(name)),
          ("to", Json::string(target)),
          ("kind", Json::string(kind)),
        ]),
      )
    }
  }
  for requirement in owner.all("knowledgeRequirement") {
    for reference in requirement.children {
      let (name, resolved) = requirement_target(model, reference)
      out.push(
        obj([
          ("name", Json::string(name)),
          ("kind", Json::string("knowledge")),
          ("resolved", Json::boolean(resolved)),
        ]),
      )
      edges.push(
        obj([
          ("from", Json::string(name)),
          ("to", Json::string(target)),
          ("kind", Json::string("knowledge")),
        ]),
      )
    }
  }
  out
}

///|
fn variable_type(model : @model.Model, node : @xml.Node) -> Json {
  let ref_name = match node.child("variable") {
    Some(variable) => type_ref(variable)
    None => ""
  }
  type_json(model, ref_name, 0)
}

///|
/// Model overview for the page: inputs with resolved types, decisions with their
/// boxed expression, knowledge models, item definitions and DRG edges.
fn summary(model : @model.Model) -> Json {
  let edges : Array[Json] = []
  let inputs : Array[Json] = []
  let decisions : Array[Json] = []
  let knowledge : Array[Json] = []
  for node in model.root.children {
    if node.uri != model.root.uri {
      continue
    }
    match node.name {
      "inputData" =>
        inputs.push(
          obj([
            ("name", Json::string(declared_name(node))),
            ("id", Json::string(node.attr("id"))),
            ("type", variable_type(model, node)),
            ("line", int_json(node.line)),
            ("column", int_json(node.column)),
          ]),
        )
      "decision" => {
        let name = declared_name(node)
        let requires = requirement_list(model, node, edges, name)
        let fields : Array[(String, Json)] = [
          ("name", Json::string(name)),
          ("id", Json::string(node.attr("id"))),
          ("type", variable_type(model, node)),
          ("requires", Json::array(requires)),
          ("line", int_json(node.line)),
          ("column", int_json(node.column)),
        ]
        match expression_of(node) {
          Some(expression) => {
            fields.push(("expression", Json::string(expression.name)))
            if expression.name == "literalExpression" {
              fields.push(("text", Json::string(expression.content("text"))))
            }
            if expression.name == "decisionTable" {
              fields.push(("table", table_json(expression)))
            }
          }
          None => fields.push(("expression", Json::string("")))
        }
        decisions.push(obj(fields))
      }
      "businessKnowledgeModel" | "decisionService" => {
        let name = declared_name(node)
        let requires = requirement_list(model, node, edges, name)
        knowledge.push(
          obj([
            ("name", Json::string(name)),
            ("id", Json::string(node.attr("id"))),
            (
              "kind",
              Json::string(
                if node.name == "decisionService" {
                  "service"
                } else {
                  "bkm"
                },
              ),
            ),
            ("requires", Json::array(requires)),
            ("line", int_json(node.line)),
            ("column", int_json(node.column)),
          ]),
        )
      }
      _ => ()
    }
  }
  let definitions = model.root
    .all("itemDefinition")
    .map(definition => {
      let shape = type_json(model, definition.attr("name"), 0)
      merge(shape, [("line", int_json(definition.line))])
    })
  obj([
    ("ok", Json::boolean(true)),
    ("name", Json::string(model.root.attr("name"))),
    ("hasImports", Json::boolean(!model.imports.is_empty())),
    ("namespace", Json::string(model.root.attr("namespace"))),
    ("inputs", Json::array(inputs)),
    ("decisions", Json::array(decisions)),
    ("knowledge", Json::array(knowledge)),
    ("itemDefinitions", Json::array(definitions)),
    ("edges", Json::array(edges)),
  ])
}
