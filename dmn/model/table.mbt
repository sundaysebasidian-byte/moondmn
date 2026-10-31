///|
priv struct Ranked {
  rank : Int32
  row : @types.Value
}

///|
fn output_name(output : @xml.Node) -> String {
  let name = output.attr("name")
  if name != "" {
    name
  } else {
    output.attr("id")
  }
}

///|
fn output_priority(
  output : @xml.Node,
  value : @types.Value,
  ctx : Map[String, @types.Value],
) -> Int32 raise @types.EngineError {
  match output.child("outputValues") {
    Some(allowed) => @eval.allowed_rank(allowed.content("text"), value, ctx)
    None => -1
  }
}

///|
fn first_value(
  outputs : Array[@xml.Node],
  row : Map[String, @types.Value],
) -> @types.Value {
  row.get(output_name(outputs[0])).unwrap_or(Null)
}

///|
fn row_value(
  outputs : Array[@xml.Node],
  row : Map[String, @types.Value],
) -> @types.Value {
  if outputs.length() == 1 {
    row.get(output_name(outputs[0])).unwrap_or(Null)
  } else {
    Context(row)
  }
}

///|
fn default_row(
  outputs : Array[@xml.Node],
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  let row = Map([])
  for output in outputs {
    let value = match output.child("defaultOutputEntry") {
      Some(entry) => @eval.feel_eval(entry.content("text"), ctx~)
      None => Null
    }
    row[output_name(output)] = value
  }
  row_value(outputs, row)
}

///|
fn aggregate(
  name : String,
  matches : Array[@types.Value],
) -> @types.Value raise @types.EngineError {
  if name == "COUNT" {
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
    match name {
      "SUM" | "C+" => n = n.add(m)
      "MIN" | "C<" => if m.compare(n) < 0 { n = m }
      "MAX" | "C>" => if m.compare(n) > 0 { n = m }
      _ => raise @types.fail("E_TABLE_AGGREGATION", name)
    }
  }
  Number(n)
}

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
  let collect = policy == "COLLECT" ||
    policy == "C+" ||
    policy == "C<" ||
    policy == "C>" ||
    policy == "C#"
  if !(collect ||
    ["UNIQUE", "ANY", "FIRST", "PRIORITY", "RULE ORDER", "OUTPUT ORDER"].contains(
      policy,
    )) {
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
    for i, entry in entries {
      let v = @eval.feel_eval(entry.content("text"), ctx~)
      if outputs[i].child("outputValues") is Some(allowed) {
        if !@eval.unary_test(allowed.content("text"), v, ctx) {
          raise @types.fail("E_OUTPUT_VALUES", "output violates allowed values")
        }
      }
      row[output_name(outputs[i])] = v
    }
    matches.push(row)
    if policy == "FIRST" {
      break
    }
  }
  if collect {
    if outputs.length() != 1 {
      if node.attr("aggregation") != "" {
        raise @types.fail(
          "E_TABLE_AGGREGATION", "aggregation requires single output",
        )
      }
    }
    let rows = matches.map(row => row_value(outputs, row))
    let agg = if node.attr("aggregation") != "" {
      node.attr("aggregation")
    } else {
      match policy {
        "C+" => "SUM"
        "C<" => "MIN"
        "C>" => "MAX"
        "C#" => "COUNT"
        _ => ""
      }
    }
    if agg == "" {
      return List(rows)
    }
    if outputs.length() != 1 {
      raise @types.fail(
        "E_TABLE_AGGREGATION", "aggregation requires single output",
      )
    }
    return aggregate(agg, rows)
  }
  if matches.is_empty() {
    if policy == "OUTPUT ORDER" {
      for output in outputs {
        if output.child("defaultOutputEntry") is Some(_) {
          return List([default_row(outputs, ctx)])
        }
      }
      return List([])
    }
    return default_row(outputs, ctx)
  }
  if policy == "RULE ORDER" || policy == "OUTPUT ORDER" {
    let rows = matches.map(row => row_value(outputs, row))
    if policy == "OUTPUT ORDER" {
      let ranked = []
      for row in matches {
        let rank = output_priority(outputs[0], first_value(outputs, row), ctx)
        ranked.push({ rank, row: row_value(outputs, row), })
      }
      // Stable insertion sort: priority order, then rule order for ties.
      for i = 1; i < ranked.length(); i = i + 1 {
        let item = ranked[i]
        let mut j = i - 1
        while j >= 0 && ranked[j].rank > item.rank {
          ranked[j + 1] = ranked[j]
          j = j - 1
        }
        ranked[j + 1] = item
      }
      return List(ranked.map(item => item.row))
    }
    return List(rows)
  }
  if policy == "PRIORITY" {
    let mut best = matches[0]
    let mut best_rank = output_priority(
      outputs[0],
      first_value(outputs, matches[0]),
      ctx,
    )
    for i = 1; i < matches.length(); i = i + 1 {
      let rank = output_priority(
        outputs[0],
        first_value(outputs, matches[i]),
        ctx,
      )
      if best_rank < 0 || (rank >= 0 && rank < best_rank) {
        best = matches[i]
        best_rank = rank
      }
    }
    return row_value(outputs, best)
  }
  if policy == "UNIQUE" && matches.length() > 1 {
    raise @types.fail("E_HIT_UNIQUE", "multiple rules matched")
  }
  if policy == "ANY" &&
    !matches
    .iter()
    .all(row => row_value(outputs, row).equals(row_value(outputs, matches[0]))) {
    raise @types.fail("E_HIT_ANY", "matched outputs differ")
  }
  row_value(outputs, matches[0])
}
