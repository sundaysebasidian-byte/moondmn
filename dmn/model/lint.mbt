///|
/// Return static model diagnostics as JSON.
pub fn lint(model : Model) -> Json {
  let findings = []
  for name, decision in model.decisions {
    for req in decision.all("informationRequirement") {
      for reference in req.children {
        let href = reference.attr("href")
        let valid = try {
          if href.has_prefix("#") ||
            href.has_prefix(model.root.attr("namespace") + "#") {
            ignore(href_id(model, href))
            true
          } else {
            model.imports.any(pair => {
              href.has_prefix(pair.1.root.attr("namespace") + "#") &&
              pair.1.ids.contains(
                href.split("#").to_array().last().unwrap_or("").to_owned(),
              )
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
      let signatures = Map([])
      let mut wildcard = false
      for rule in expr.all("rule") {
        let tests = rule.all("inputEntry").map(n => n.content("text"))
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
        if tests.iter().all(t => t == "-") {
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
  let predicates = table
    .all("rule")
    .map(rule => rule.all("inputEntry").map(entry => entry.content("text")))
  if predicates.iter().any(rule => rule.length() != domains.length()) {
    return false
  }
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
        if !(@eval.unary_test(predicate, tuple[i], Map([])) catch {
            _ => return false
          }) {
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
