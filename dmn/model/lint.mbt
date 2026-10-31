///|
/// Return static model diagnostics as JSON.
pub fn lint(model : Model) -> Json {
  let findings = []
  for name, decision in model.decisions {
    for req in decision.all("informationRequirement") {
      for reference in req.children {
        let href = reference.attr("href")
        if href.has_prefix("#") {
          let id = href.strip_prefix("#").unwrap().to_owned()
          if !model.ids.contains(id) {
            findings.push(
              finding(
                "E_REFERENCE",
                name,
                "undefined reference " + href,
                reference,
              ),
            )
          }
        } else {
          findings.push(
            finding(
              "E_IMPORT_UNSUPPORTED", name, "external reference", reference,
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
      if !wildcard {
        findings.push(
          finding(
            "W_POSSIBLE_GAP", name, "no catch-all rule; domain coverage requires review",
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
