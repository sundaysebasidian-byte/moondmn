// Which rules of a decision table matched.
//
// The engine returns only the table's final value. To recover the matching
// rows without touching the engine, each table is replayed as a synthetic
// RULE ORDER table that keeps the original input columns and entries and
// answers with the rule number. It is appended to the same model, so
// requirements, type coercion and input values behave as in the real run.

///|
/// Decisions reachable from `name` through required decisions, skipping those
/// the caller supplied as input.
fn dependency_closure(
  model : @model.Model,
  name : String,
  supplied : Map[String, @types.Value],
) -> Array[String] {
  let seen : Array[String] = []
  fn visit(current : String, depth : Int32) -> Unit {
    if seen.contains(current) || depth > 64 {
      return
    }
    match model.decisions.get(current) {
      None => return
      Some(node) => {
        seen.push(current)
        for requirement in node.all("informationRequirement") {
          for reference in requirement.children {
            if reference.name != "requiredDecision" {
              continue
            }
            let (target, resolved) = requirement_target(model, reference)
            if resolved && !supplied.contains(target) {
              visit(target, depth + 1)
            }
          }
        }
      }
    }
  }

  visit(name, 0)
  seen
}

///|
fn escape_xml(text : String) -> String {
  let out = StringBuilder()
  for ch in text {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' => out.write_string("&quot;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
/// Namespace prefix of the closing `definitions` tag and where that tag starts.
fn closing_tag(xml : String) -> (String, Int32)? {
  let end = match xml.rev_find("definitions>") {
    Some(index) => index
    None => return None
  }
  let mut start = end
  // walk back to the "</" that opens the closing tag
  while start >= 2 {
    if xml[start - 2] == '<' && xml[start - 1] == '/' {
      let prefix = xml[start:end].to_owned()
      return Some((prefix, start - 2))
    }
    start = start - 1
  }
  None
}

///|
fn replay_xml(
  prefix : String,
  id : String,
  decision : @xml.Node,
  table : @xml.Node,
) -> String {
  let out = StringBuilder()
  let tag = fn(name : String) { prefix + name }
  out.write_string("<\{tag("decision")} id=\"\{id}\" name=\"\{id}\">")
  for kind in ["informationRequirement", "knowledgeRequirement"] {
    for requirement in decision.all(kind) {
      out.write_string("<\{tag(kind)}>")
      for reference in requirement.children {
        let name = tag(reference.name)
        out.write_string(
          "<\{name} href=\"\{escape_xml(reference.attr("href"))}\"/>",
        )
      }
      out.write_string("</\{tag(kind)}>")
    }
  }
  out.write_string("<\{tag("decisionTable")} hitPolicy=\"RULE ORDER\">")
  for input in table.all("input") {
    out.write_string("<\{tag("input")}>")
    if input.child("inputExpression") is Some(expression) {
      out.write_string(
        "<\{tag("inputExpression")}><\{tag("text")}>\{escape_xml(expression.content("text"))}</\{tag("text")}></\{tag("inputExpression")}>",
      )
    }
    if input.child("inputValues") is Some(values) {
      out.write_string(
        "<\{tag("inputValues")}><\{tag("text")}>\{escape_xml(values.content("text"))}</\{tag("text")}></\{tag("inputValues")}>",
      )
    }
    out.write_string("</\{tag("input")}>")
  }
  out.write_string("<\{tag("output")} name=\"rule\"/>")
  for index, rule in table.all("rule") {
    out.write_string("<\{tag("rule")}>")
    for entry in rule.all("inputEntry") {
      out.write_string(
        "<\{tag("inputEntry")}><\{tag("text")}>\{escape_xml(entry.content("text"))}</\{tag("text")}></\{tag("inputEntry")}>",
      )
    }
    out.write_string(
      "<\{tag("outputEntry")}><\{tag("text")}>\{index + 1}</\{tag("text")}></\{tag("outputEntry")}>",
    )
    out.write_string("</\{tag("rule")}>")
  }
  out.write_string("</\{tag("decisionTable")}></\{tag("decision")}>")
  out.to_string()
}

///|
/// Hit rules for every decision table in `names`: `{decision: {hitPolicy, hits}}`
/// where `hits` are zero-based rule indexes. Tables that cannot be replayed are
/// left out.
fn table_hits(
  xml : String,
  model : @model.Model,
  names : Array[String],
  scope : () -> Map[String, @types.Value],
) -> Json {
  let result : Map[String, Json] = Map([])
  let tables : Array[(String, @xml.Node, @xml.Node)] = []
  for name in names {
    if model.decisions.get(name) is Some(decision) {
      if expression_of(decision) is Some(table) && table.name == "decisionTable" {
        tables.push((name, decision, table))
      }
    }
  }
  if tables.is_empty() {
    return Json::object(result)
  }
  let (prefix, position) = match closing_tag(xml) {
    Some(found) => found
    None => return Json::object(result)
  }
  let replay = StringBuilder()
  for index, entry in tables {
    replay.write_string(replay_xml(prefix, "__hits_\{index}", entry.1, entry.2))
  }
  let extended = xml[:position].to_owned() +
    replay.to_string() +
    xml[position:].to_owned()
  let replayed = @model.parse_model(extended) catch {
    _ => return Json::object(result)
  }
  for index, entry in tables {
    let policy = if entry.2.attr("hitPolicy") == "" {
      "UNIQUE"
    } else {
      entry.2.attr("hitPolicy")
    }
    let rows = @model.evaluate_decision(replayed, "__hits_\{index}", scope()) catch {
      _ => continue
    }
    let hits : Array[Json] = []
    let numbers = match rows {
      List(items) => items
      other => [other]
    }
    for item in numbers {
      if item is Number(n) {
        hits.push(int_json((n.to_int() catch { _ => 1 }) - 1))
      }
    }
    if policy == "FIRST" && hits.length() > 1 {
      hits.truncate(1)
    }
    result[entry.0] = obj([
      ("hitPolicy", Json::string(policy)),
      ("hits", Json::array(hits)),
    ])
  }
  Json::object(result)
}
