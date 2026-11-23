///|
/// Return static model diagnostics as JSON.
pub fn lint(model : Model) -> Json {
  let findings = []
  for name, decision in model.decisions {
    let requirements = decision.all("informationRequirement")
    requirements.append(decision.all("knowledgeRequirement"))
    for req in requirements {
      for reference in req.children {
        if !is_requirement_reference(req, reference) {
          continue
        }
        let href = reference.attr("href")
        let valid = try {
          if href.has_prefix("#") ||
            href.has_prefix(model.root.attr("namespace") + "#") {
            let target = href_id(model, href)
            if reference.name == "requiredKnowledge" {
              check_requirement_target(model, reference, target)
            }
            true
          } else {
            model.imports.any(pair => {
              if href.has_prefix(pair.1.root.attr("namespace") + "#") {
                let target = href_id(pair.1, href)
                if reference.name == "requiredKnowledge" {
                  check_requirement_target(pair.1, reference, target)
                }
                true
              } else {
                false
              }
            })
          }
        } catch {
          _ => false
        }
        if !valid {
          findings.push(
            finding(
              "E_REFERENCE",
              name,
              "undefined reference " + href,
              reference,
            ),
          )
        }
      }
    }
    let expr = expression(decision) catch { _ => continue }
    if expr.name == "decisionTable" {
      let policy = expr.attr("hitPolicy")
      if expr.attr("aggregation") != "" &&
        !["COLLECT", "C+", "C<", "C>", "C#"].contains(policy) {
        findings.push(
          finding(
            "W_IGNORED_AGGREGATION", name, "aggregation applies only to Collect policies",
            expr,
          ),
        )
      }
      let signatures = Map([])
      let columns = expr.all("input").length()
      let outputs = expr.all("output").length()
      let mut wildcard = false
      for rule in expr.all("rule") {
        let cells = rule.all("inputEntry")
        let tests = cells.map(n => n.content("text"))
        let supported = cells
          .iter()
          .all(cell => lint_feel_language(model, cell))
        if !supported {
          for cell in cells {
            if !lint_feel_language(model, cell) {
              findings.push(
                finding("E_LANGUAGE", name, "non-FEEL input entry", cell),
              )
            }
          }
        }
        let signature = Json(tests).stringify()
        if signatures.contains(signature) {
          findings.push(
            finding(
              "W_IDENTICAL_RULE_OVERLAP", name, "identical predicates overlap if satisfiable",
              rule,
            ),
          )
        }
        signatures[signature] = true
        if supported &&
          outputs > 0 &&
          tests.length() == columns &&
          rule.all("outputEntry").length() == outputs &&
          tests.iter().all(t => t == "-" || t == "") {
          wildcard = true
        }
      }
      if !wildcard && !proves_coverage(model, expr) {
        findings.push(
          finding(
            "W_POSSIBLE_GAP", name, "no catch-all rule; domain coverage requires manual inspection",
            expr,
          ),
        )
      }
    }
  }
  Json::array(findings)
}

///|
fn finding(
  code : String,
  decision : String,
  message : String,
  node : @xml.Node,
) -> Json {
  Json::object(
    Map([
      ("code", Json(code)),
      ("decision", Json(decision)),
      ("message", Json(message)),
      ("line", Json(node.line)),
      ("column", Json(node.column)),
    ]),
  )
}

///|
fn lint_feel_language(model : Model, node : @xml.Node) -> Bool {
  try {
    require_feel_language(model, node)
    true
  } catch {
    _ => false
  }
}

///|
fn enumeration(text : String) -> Array[@types.Value]? {
  let result = @eval.feel_eval("[" + text + "]") catch { _ => return None }
  match result {
    List(values) if !values.is_empty() && values.length() <= 4096 => {
      if values
        .iter()
        .any(v => {
          v is Range(_) ||
          v is List(_) ||
          v is Context(_) ||
          v is Function(_) ||
          v is Null
        }) {
        return None
      }
      Some(values)
    }
    _ => None
  }
}

///|
fn declared_domain(
  model : Model,
  name : String,
  depth : Int32,
) -> Array[@types.Value]? {
  if depth > 32 {
    return None
  }
  if imported_type(model, name) is Some((child, rest)) {
    return declared_domain(child, rest, depth + 1)
  }
  for definition in model.root.all("itemDefinition") {
    if definition.attr("name") == name {
      if definition.child("allowedValues") is Some(allowed) {
        return enumeration(allowed.content("text"))
      }
      return declared_domain(model, item_type_name(definition), depth + 1)
    }
  }
  None
}

///|
fn proves_coverage(model : Model, table : @xml.Node) -> Bool {
  let domains : Array[Array[@types.Value]] = []
  let mut combinations = 1
  for input in table.all("input") {
    let domain = if input.child("inputValues") is Some(allowed) {
      if !lint_feel_language(model, allowed) {
        return false
      }
      enumeration(allowed.content("text"))
    } else {
      let expression = match input.child("inputExpression") {
        Some(e) => e.content("text")
        None => return false
      }
      let mut found : Array[@types.Value]? = None
      for data in model.root.all("inputData") {
        if data.attr("name") == expression &&
          data.child("variable") is Some(variable) {
          found = declared_domain(model, variable.attr("typeRef"), 0)
        }
      }
      found
    }
    match domain {
      Some(values) => {
        if values.length() > 4096 / combinations {
          return false
        }
        combinations = combinations * values.length()
        domains.push(values)
      }
      None => return false
    }
  }
  if domains.is_empty() {
    return false
  }
  let output_columns = table.all("output").length()
  if output_columns == 0 ||
    table
    .all("rule")
    .iter()
    .any(rule => rule.all("outputEntry").length() != output_columns) {
    return false
  }
  let rules = table.all("rule")
  if rules
    .iter()
    .any(rule => {
      rule
      .all("inputEntry")
      .iter()
      .any(entry => !lint_feel_language(model, entry))
    }) {
    return false
  }
  let predicates = rules.map(rule => {
    rule.all("inputEntry").map(entry => entry.content("text"))
  })
  if predicates.iter().any(rule => rule.length() != domains.length()) {
    return false
  }
  let compiled : Map[String, @parser.Test] = Map([])
  let lexical_names = @builtins.names()
  lexical_names.push("?")
  for combination = 0; combination < combinations; combination = combination + 1 {
    let tuple = []
    let mut index = combination
    for domain in domains {
      tuple.push(domain[index % domain.length()])
      index = index / domain.length()
    }
    let mut covered = false
    for rule in predicates {
      let mut matched = true
      for i, predicate in rule {
        let hit = try {
          let check = match compiled.get(predicate) {
            Some(check) => check
            None => {
              let check = @parser.compile_test(predicate, names=lexical_names)
              if compiled.length() < 256 && predicate.length() <= 4096 {
                compiled[predicate] = check
              }
              check
            }
          }
          @eval.test_matches(check, tuple[i], Map([("?", tuple[i])]))
        } catch {
          _ => return false
        }
        if !hit {
          matched = false
        }
      }
      if matched {
        covered = true
        break
      }
    }
    if !covered {
      return false
    }
  }
  true
}
