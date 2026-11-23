///|
priv struct Ranked {
  rank : Array[Int32]
  row : @types.Value
  ordinal : Int32
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
fn row_ranks(
  outputs : Array[@xml.Node],
  row : Map[String, @types.Value],
  ctx : Map[String, @types.Value],
) -> Array[Int32] raise @types.EngineError {
  let ranks = []
  for output in outputs {
    if output.child("outputValues") is Some(_) {
      let rank = output_priority(
        output,
        row.get(output_name(output)).unwrap_or(Null),
        ctx,
      )
      // Any unranked match follows all explicitly ordered values.
      ranks.push(if rank < 0 { 2147483647 } else { rank })
    }
  }
  ranks
}

///|
fn compare_ranks(a : Array[Int32], b : Array[Int32]) -> Int32 {
  for i, item in a {
    let order = item.compare(b[i])
    if order != 0 {
      return order
    }
  }
  0
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
  model : Model,
  outputs : Array[@xml.Node],
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  let row = Map([])
  for output in outputs {
    let value = match output.child("defaultOutputEntry") {
      Some(entry) => {
        let value = eval_literal(model, entry, ctx)
        if output.child("outputValues") is Some(allowed) {
          require_feel_language(model, allowed)
          if !@eval.unary_test(allowed.content("text"), value, ctx) {
            raise @types.fail(
              "E_OUTPUT_VALUES", "default output violates allowed values",
            )
          }
        }
        value
      }
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
  if name == "SUM" || name == "C+" {
    let values = []
    for value in matches {
      match value {
        Number(n) => values.push(n)
        _ => raise @types.fail("E_TABLE_AGGREGATION", "numeric output required")
      }
    }
    return Number(@types.Decimal::sum(values))
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
      "MIN" | "C<" => if m.compare(n) < 0 { n = m }
      "MAX" | "C>" => if m.compare(n) > 0 { n = m }
      _ => raise @types.fail("E_TABLE_AGGREGATION", name)
    }
  }
  Number(n)
}

///|
// Numbers consisting of at most nine ASCII digits lex independently of
// scope. Prepare only this error-free subset; all other rules remain lazy.
fn collect_integer_table_tests(
  node : @xml.Node,
  parsed : Map[String, @parser.Test],
) -> Unit {
  if parsed.length() >= 256 {
    return
  }
  if node.name == "decisionTable" {
    for rule in node.all("rule") {
      for entry in rule.all("inputEntry") {
        if parsed.length() >= 256 {
          return
        }
        let source = entry.content("text")
        if source.length() > 0 &&
          source.length() <= 9 &&
          !parsed.contains(source) {
          let mut number = 0
          let mut valid = true
          for ch in source {
            if ch < '0' || ch > '9' {
              valid = false
              break
            }
            number = number * 10 + ch.to_int() - '0'.to_int()
          }
          if valid {
            parsed[source] = @parser.ExprTest(
              @parser.Lit(Number(@types.decimal_int(number))),
            )
          }
        }
      }
    }
  }
  for child in node.children {
    if child.uri == node.uri {
      collect_integer_table_tests(child, parsed)
    }
  }
}

///|
fn table(
  model : Model,
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
  let aggregation = node.attr("aggregation")
  if collect &&
    aggregation != "" &&
    !["SUM", "COUNT", "MIN", "MAX", "C+", "C<", "C>"].contains(aggregation) {
    raise @types.fail("E_TABLE_AGGREGATION", aggregation)
  }
  let inputs = node.all("input")
  let outputs = node.all("output")
  if outputs.is_empty() {
    raise @types.fail("E_TABLE_SHAPE", "no output columns")
  }
  if outputs.length() > 1 {
    let names : Map[String, Bool] = Map([])
    for output in outputs {
      let name = output_name(output)
      if names.contains(name) {
        raise @types.fail("E_TABLE_SHAPE", "duplicate output name: " + name)
      }
      names[name] = true
    }
  }
  let values = []
  for input in inputs {
    let expr = match input.child("inputExpression") {
      Some(n) => n
      None => raise @types.fail("E_TABLE_SHAPE", "missing inputExpression")
    }
    let v = eval_literal(model, expr, ctx)
    if input.child("inputValues") is Some(allowed) {
      require_feel_language(model, allowed)
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
      require_feel_language(model, test_node)
      let source = test_node.content("text")
      let hit = match model.integer_table_tests.get(source) {
        Some(prepared) =>
          @eval.test_matches(
            prepared,
            values[i],
            scope_with(ctx, "?", values[i]),
          )
        None => @eval.unary_test(source, values[i], ctx)
      }
      if !hit {
        matched = false
      }
    }
    if !matched {
      continue
    }
    let row = Map([])
    for i, entry in entries {
      let v = eval_literal(model, entry, ctx)
      if outputs[i].child("outputValues") is Some(allowed) {
        require_feel_language(model, allowed)
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
  if matches.is_empty() &&
    outputs.iter().any(o => o.child("defaultOutputEntry") is Some(_)) {
    return default_row(model, outputs, ctx)
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
          return List([default_row(model, outputs, ctx)])
        }
      }
      return List([])
    }
    return default_row(model, outputs, ctx)
  }
  if policy == "OUTPUT ORDER" {
    let ranked = []
    for ordinal, row in matches {
      ranked.push({
        rank: row_ranks(outputs, row, ctx),
        row: row_value(outputs, row),
        ordinal,
      })
    }
    ranked.sort_by((a, b) => {
      let order = compare_ranks(a.rank, b.rank)
      if order != 0 {
        order
      } else {
        a.ordinal.compare(b.ordinal)
      }
    })
    return List(ranked.map(item => item.row))
  }
  if policy == "RULE ORDER" {
    return List(matches.map(row => row_value(outputs, row)))
  }
  if policy == "PRIORITY" {
    let mut best = matches[0]
    let mut best_rank = row_ranks(outputs, best, ctx)
    for i = 1; i < matches.length(); i = i + 1 {
      let rank = row_ranks(outputs, matches[i], ctx)
      if compare_ranks(rank, best_rank) < 0 {
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
