///|
pub fn table(
  node : @xml.Node,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  let policy = if node.attr("hitPolicy") == "" {
    "UNIQUE"
  } else {
    node.attr("hitPolicy")
  }
  if !["UNIQUE", "ANY", "FIRST", "RULE ORDER", "COLLECT"].contains(policy) {
    raise @types.fail("E_HIT_POLICY_UNSUPPORTED", policy)
  }
  let inputs = node.all("input")
  let outputs = node.all("output")
  if outputs.is_empty() {
    raise @types.fail("E_TABLE_SHAPE", "no output columns")
  }
  let values = []
  for input in inputs {
    let expr = match input.child("inputExpression") {
      Some(n) => n
      None => raise @types.fail("E_TABLE_SHAPE", "missing inputExpression")
    }
    let v = @eval.feel_eval(expr.content("text"), ctx~)
    if input.child("inputValues") is Some(allowed) {
      if !@eval.unary_test(allowed.content("text"), v, ctx) {
        raise @types.fail("E_INPUT_VALUES", "input violates allowed values")
      }
    }
    values.push(v)
  }
  let matches = []
  for rule in node.all("rule") {
    let tests = rule.all("inputEntry")
    let entries = rule.all("outputEntry")
    if tests.length() != inputs.length() || entries.length() != outputs.length() {
      raise @types.fail("E_TABLE_SHAPE", "rule column count mismatch")
    }
    let mut matched = true
    for i, test_node in tests {
      if !@eval.unary_test(test_node.content("text"), values[i], ctx) {
        matched = false
      }
    }
    if !matched {
      continue
    }
    let row = Map([])
    let mut single : @types.Value = Null
    for i, entry in entries {
      let v = @eval.feel_eval(entry.content("text"), ctx~)
      if outputs[i].child("outputValues") is Some(allowed) {
        if !@eval.unary_test(allowed.content("text"), v, ctx) {
          raise @types.fail("E_OUTPUT_VALUES", "output violates allowed values")
        }
      }
      row[outputs[i].attr("name")] = v
      single = v
    }
    matches.push(if outputs.length() == 1 { single } else { Context(row) })
    if policy == "FIRST" {
      break
    }
  }
  if policy == "RULE ORDER" {
    return List(matches)
  }
  if policy == "COLLECT" {
    let agg = node.attr("aggregation")
    if agg == "" {
      return List(matches)
    }
    if outputs.length() != 1 {
      raise @types.fail(
        "E_TABLE_AGGREGATION", "aggregation requires single output",
      )
    }
    if agg == "COUNT" {
      return Number(@types.decimal(matches.length().to_string()))
    }
    if matches.is_empty() {
      return Null
    }
    let mut n = match matches[0] {
      Number(n) => n
      _ => raise @types.fail("E_TABLE_AGGREGATION", "numeric output required")
    }
    for i = 1; i < matches.length(); i = i + 1 {
      let m = match matches[i] {
        Number(m) => m
        _ => raise @types.fail("E_TABLE_AGGREGATION", "numeric output required")
      }
      match agg {
        "SUM" => n = n.add(m)
        "MIN" => if m.compare(n) < 0 { n = m }
        "MAX" => if m.compare(n) > 0 { n = m }
        _ => raise @types.fail("E_TABLE_AGGREGATION", agg)
      }
    }
    return Number(n)
  }
  if matches.is_empty() {
    let row = Map([])
    let mut single : @types.Value = Null
    for output in outputs {
      let v = match output.child("defaultOutputEntry") {
        Some(entry) => @eval.feel_eval(entry.content("text"), ctx~)
        None => @types.Null
      }
      row[output.attr("name")] = v
      single = v
    }
    return if outputs.length() == 1 { single } else { Context(row) }
  }
  if policy == "UNIQUE" && matches.length() > 1 {
    raise @types.fail("E_HIT_UNIQUE", "multiple rules matched")
  }
  if policy == "ANY" && !matches.iter().all(v => v == matches[0]) {
    raise @types.fail("E_HIT_ANY", "matched outputs differ")
  }
  matches[0]
}
