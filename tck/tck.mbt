///|
/// TCK values are parsed without a binary floating-point conversion.
pub fn value(node : @xml.Node) -> @types.Value raise @types.EngineError {
  if node.child("list") is Some(list) {
    return List(list.all("item").map(value))
  }
  let components = node.all("component")
  if !components.is_empty() {
    let out = Map([])
    for c in components {
      out[c.attr("name")] = value(c)
    }
    return Context(out)
  }
  let v = match node.child("value") {
    Some(v) => v
    None => raise @types.fail("E_TCK_VALUE", "missing value")
  }
  if v.attributes.values().any(x => x == "true") &&
    v.attributes.keys().any(k => k.has_suffix(":nil")) {
    return Null
  }
  let mut kind = "xsd:string"
  for k, v in v.attributes {
    if k.has_suffix(":type") {
      kind = v
    }
  }
  let text = v.text.trim().to_owned()
  match kind {
    "xsd:string" | "xs:string" => Text(v.text)
    "xsd:boolean" | "xs:boolean" =>
      if text == "true" || text == "1" {
        Boolean(true)
      } else if text == "false" || text == "0" {
        Boolean(false)
      } else {
        raise @types.fail("E_TCK_VALUE", "invalid boolean")
      }
    "xsd:decimal"
    | "xs:decimal"
    | "xsd:double"
    | "xs:double"
    | "xsd:integer"
    | "xs:integer" => Number(@types.decimal(text))
    other => raise @types.fail("E_TCK_TYPE_UNSUPPORTED", other)
  }
}

///|
/// Strict recursive comparison. Temporal equivalence and tolerance remain unsupported.
pub fn equal(a : @types.Value, b : @types.Value) -> Bool {
  match (a, b) {
    (Number(x), Number(y)) => x.compare(y) == 0
    (List(xs), List(ys)) => {
      if xs.length() != ys.length() {
        return false
      }
      for i, x in xs {
        if !equal(x, ys[i]) {
          return false
        }
      }
      true
    }
    (Context(xs), Context(ys)) =>
      xs.length() == ys.length() &&
      xs
      .iter()
      .all(pair => {
        match ys.get(pair.0) {
          Some(v) => equal(pair.1, v)
          None => false
        }
      })
    _ => a == b
  }
}

///|
fn error_code(e : @types.EngineError) -> String {
  match e {
    Failure(code, _, _, _) => code
  }
}

///|
fn check_case(
  model : @model.Model,
  case : @xml.Node,
) -> Unit raise @types.EngineError {
  if case.attr("type") != "" && case.attr("type") != "decision" {
    raise @types.fail("E_TCK_CASE_UNSUPPORTED", case.attr("type"))
  }
  let inputs = Map([])
  for input in case.all("inputNode") {
    inputs[input.attr("name")] = value(input)
  }
  let results = case.all("resultNode")
  if results.is_empty() {
    raise @types.fail("E_TCK_RESULT", "no result nodes")
  }
  for result in results {
    let actual = Ok(
      @model.evaluate_decision(model, result.attr("name"), inputs),
    ) catch {
      e => Err(e)
    }
    if result.attr("errorResult") == "true" {
      // Unsupported implementation paths must never satisfy an expected semantic error.
      match actual {
        Err(e) =>
          if ![
              "E_HIT_UNIQUE", "E_HIT_ANY", "E_INPUT_VALUES", "E_OUTPUT_VALUES", "E_DIV_ZERO",
            ].contains(error_code(e)) {
            raise e
          }
        Ok(_) => raise @types.fail("E_TCK_EXPECTED_ERROR", "expected error")
      }
    } else {
      let expected = match result.child("expected") {
        Some(n) => value(n)
        None => raise @types.fail("E_TCK_RESULT", "missing expected")
      }
      match actual {
        Ok(v) =>
          if !equal(v, expected) {
            raise @types.fail(
              "E_TCK_MISMATCH",
              "actual " +
              v.json().stringify() +
              ", expected " +
              expected.json().stringify(),
            )
          }
        Err(e) => raise e
      }
    }
  }
}

///|
fn collect(
  dir : String,
  out : Array[String],
  depth : Int32,
) -> Unit raise Error {
  if depth > 16 {
    raise @types.fail("E_LIMIT", "TCK directory depth")
  }
  let names = @fs.read_dir(dir).to_owned()
  names.sort()
  for name in names {
    let path = dir + "/" + name
    if @fs.is_dir(path) {
      collect(path, out, depth + 1)
    } else if name.contains("-test-") && name.has_suffix(".xml") {
      out.push(path)
    }
  }
}

///|
pub fn run(directory : String) -> Json raise Error {
  let files = []
  collect(directory, files, 0)
  let rows = []
  let mut total = 0
  let mut passed = 0
  let mut infrastructure = 0
  let categories : Map[String, Int32] = Map([])
  for path in files {
    let root = @xml.parse(@fs.read_file_to_string(path))
    let model_name = root.content("modelName")
    let pieces = path.split("/").to_array()
    ignore(pieces.pop())
    let model_path = pieces.join("/") + "/" + model_name
    let model = Ok(@model.parse_model(@fs.read_file_to_string(model_path))) catch {
      e => Err(e)
    }
    let cases = root.all("testCase")
    if cases.is_empty() {
      infrastructure = infrastructure + 1
    }
    for case in cases {
      total = total + 1
      let outcome = try {
        match model {
          Ok(m) => check_case(m, case)
          Err(e) => raise e
        }
        "PASS"
      } catch {
        @types.Failure(code, _, _, _) => code
        _ => "E_IO"
      }
      if outcome == "PASS" {
        passed = passed + 1
      } else {
        categories[outcome] = categories.get(outcome).unwrap_or(0) + 1
      }
      rows.push(
        Json::object(
          Map([
            ("file", Json(path)),
            ("id", Json(case.attr("id"))),
            ("status", Json(outcome)),
          ]),
        ),
      )
    }
  }
  if files.is_empty() {
    raise @types.fail("E_TCK_EMPTY", "no TCK files found")
  }
  let reasons = Map([])
  for k, v in categories {
    reasons[k] = Json(v)
  }
  Json::object(
    Map([
      ("total", Json(total)),
      ("passed", Json(passed)),
      ("failed", Json(total - passed)),
      ("skipped", Json(0)),
      ("empty_files", Json(infrastructure)),
      ("failures", Json::object(reasons)),
      ("cases", Json::array(rows)),
    ]),
  )
}
