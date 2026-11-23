///|
fn fixture_nil(node : @xml.Node) -> Bool raise @types.EngineError {
  let schema_instance = "http://www.w3.org/2001/XMLSchema-instance"
  match node.attr_namespace(schema_instance, "nil") {
    None => false
    Some(flag) =>
      match flag.trim().to_owned() {
        "false" | "0" => false
        "true" | "1" => {
          if !node.children.is_empty() || !node.text.is_empty() {
            raise @types.fail("E_TCK_VALUE", "nil element must be empty")
          }
          true
        }
        _ => raise @types.fail("E_TCK_VALUE", "invalid xsi:nil")
      }
  }
}

///|
/// TCK values are parsed without a binary floating-point conversion.
pub fn value(node : @xml.Node) -> @types.Value raise @types.EngineError {
  let lists = node.all("list")
  let components = node.all("component")
  let scalars = node.all("value")
  let shapes = lists.length() + scalars.length() + (if components.is_empty() { 0 } else { 1 })
  if shapes != 1 {
    raise @types.fail("E_TCK_VALUE", "expected exactly one list, context or scalar value")
  }
  if lists.length() == 1 {
    let list = lists[0]
    return if fixture_nil(list) { Null } else { List(list.all("item").map(value)) }
  }
  if !components.is_empty() {
    let out = Map([])
    for c in components {
      let name = c.attr("name")
      if out.contains(name) {
        raise @types.fail("E_TCK_VALUE", "duplicate context field: " + name)
      }
      out[name] = if fixture_nil(c) { Null } else { value(c) }
    }
    return Context(out)
  }
  let v = scalars[0]
  let schema_instance = "http://www.w3.org/2001/XMLSchema-instance"
  if fixture_nil(v) {
    return Null
  }
  let kind = match v.attr_namespace(schema_instance, "type") {
    Some(raw) => schema_type_name(v, raw)
    None => "xsd:string"
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
    "xsd:decimal" | "xs:decimal" => {
      if text.contains("e") || text.contains("E") {
        raise @types.fail("E_TCK_VALUE", "decimal lexical form cannot have an exponent")
      }
      Number(@types.decimal(text)) catch {
        @types.Failure("E_DECIMAL_SYNTAX", _, _, _) =>
          raise @types.fail("E_TCK_VALUE", "invalid decimal lexical form")
        e => raise e
      }
    }
    "xsd:double"
    | "xs:double"
    | "xsd:float"
    | "xs:float" => Number(@types.decimal(text))
    "xsd:integer"
    | "xs:integer"
    | "xsd:int"
    | "xs:int"
    | "xsd:long"
    | "xs:long"
    | "xsd:short"
    | "xs:short"
    | "xsd:byte"
    | "xs:byte"
    | "xsd:nonNegativeInteger"
    | "xs:nonNegativeInteger" => {
      let digits = if text.has_prefix("-") || text.has_prefix("+") {
        text[1:]
      } else {
        text[:]
      }
      if digits.is_empty() || !digits.iter().all(ch => ch >= '0' && ch <= '9') {
        raise @types.fail("E_TCK_VALUE", "invalid integer lexical form")
      }
      let value = @types.decimal(text)
      let bounds = match kind {
        "xsd:byte" | "xs:byte" => Some(("-128", "127"))
        "xsd:short" | "xs:short" => Some(("-32768", "32767"))
        "xsd:int" | "xs:int" => Some(("-2147483648", "2147483647"))
        "xsd:long" | "xs:long" =>
          Some(("-9223372036854775808", "9223372036854775807"))
        _ => None
      }
      if (kind.has_suffix("nonNegativeInteger") && value.is_negative()) ||
        (
          bounds is Some((lo, hi)) &&
          (
            value.compare(@types.decimal(lo)) < 0 ||
            value.compare(@types.decimal(hi)) > 0
          )
        ) {
        raise @types.fail(
          "E_TCK_VALUE", "integer is outside the declared XML Schema subtype",
        )
      }
      Number(value)
    }
    "xsd:date" | "xs:date" => Date(@types.parse_date(text))
    "xsd:time" | "xs:time" => Time(@types.parse_time(text))
    "xsd:dateTime" | "xs:dateTime" | "xsd:date-time" | "xs:date-time" =>
      DateTime(@types.parse_datetime(text))
    "xsd:duration" | "xs:duration" => {
      let (days, months) = @types.parse_duration(text)
      if text.contains("Y") || (text.contains("M") && !text.contains("T")) {
        YearsMonths(months)
      } else {
        DaysSeconds(days)
      }
    }
    "xsd:dayTimeDuration"
    | "xs:dayTimeDuration"
    | "xsd:yearMonthDuration"
    | "xs:yearMonthDuration" => {
      let (days, months) = @types.parse_duration(text)
      let calendar = text.contains("Y") ||
        (text.contains("M") && !text.contains("T"))
      if calendar != kind.has_suffix("yearMonthDuration") {
        raise @types.fail(
          "E_TCK_VALUE", "duration is outside the declared XML Schema subtype",
        )
      }
      if calendar {
        YearsMonths(months)
      } else {
        DaysSeconds(days)
      }
    }
    other => raise @types.fail("E_TCK_TYPE_UNSUPPORTED", other)
  }
}

///|
fn schema_type_name(
  node : @xml.Node,
  raw : String,
) -> String raise @types.EngineError {
  let raw = raw.trim().to_owned()
  let (prefix, name) = match raw.find(":") {
    Some(at) => (raw[:at].to_owned(), raw[at + 1:].to_owned())
    None => ("", raw)
  }
  match node.namespace_uri(prefix) {
    Some("http://www.w3.org/2001/XMLSchema") => "xsd:" + name
    // Compatibility with older fixture snippets using these undeclared prefixes.
    None if prefix == "xs" || prefix == "xsd" => raw
    _ => raise @types.fail("E_TCK_TYPE_UNSUPPORTED", raw)
  }
}

///|
/// Recursive comparison with the TCK numeric tolerance of 1e-8.
pub fn equal(
  a : @types.Value,
  b : @types.Value,
) -> Bool raise @types.EngineError {
  match (a, b) {
    (Number(x), Number(y)) =>
      x.add(y.negate()).abs().compare(@types.decimal("0.00000001")) <= 0
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
    _ => a.equals(b)
  }
}

///|
fn error_code(e : @types.EngineError) -> String {
  match e {
    Failure(code, _, _, _) => code
  }
}

///|
fn sole_output(
  outputs : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  for _, v in outputs {
    return v
  }
  raise @types.fail("E_DMN_SERVICE", "decision service has no outputs")
}

///|
fn case_value(
  model : @model.Model,
  kind : String,
  invocable : String,
  result : @xml.Node,
  inputs : Map[String, @types.Value],
  clock : (() -> @types.DateTime)?,
) -> @types.Value raise @types.EngineError {
  let inputs = @eval.with_clock(inputs, clock)
  if kind == "bkm" {
    @model.evaluate_bkm(model, invocable, inputs)
  } else if kind == "decisionService" {
    let outputs = @model.evaluate_service(model, invocable, inputs)
    match outputs.get(result.attr("name")) {
      Some(v) => v
      None =>
        if outputs.length() == 1 {
          sole_output(outputs)
        } else {
          raise @types.fail(
            "E_TCK_RESULT",
            "unknown output decision: " + result.attr("name"),
          )
        }
    }
  } else {
    @model.evaluate_decision(model, result.attr("name"), inputs)
  }
}

///|
/// Error codes that represent a genuine semantic failure, as opposed to an
/// implementation limitation that must never satisfy an expected error.
fn semantic_error(code : String) -> Bool {
  [
    "E_HIT_UNIQUE", "E_HIT_ANY", "E_INPUT_VALUES", "E_OUTPUT_VALUES", "E_DIV_ZERO",
    "E_NUMBER", "E_DECIMAL_RANGE", "E_DECIMAL_SYNTAX", "E_TYPE", "E_ARITY", "E_INPUT_MISSING",
    "E_DMN_SERVICE", "E_DATE_INVALID", "E_TIME_INVALID", "E_DATETIME_INVALID", "E_DURATION_INVALID",
    "E_DATE_RANGE", "E_TEMPORAL", "E_RANGE", "E_REGEX",
  ].contains(code)
}

///|
fn check_case(
  model : @model.Model,
  case : @xml.Node,
  clock : (() -> @types.DateTime)?,
) -> Unit raise @types.EngineError {
  let kind = case.attr("type")
  if !["", "decision", "bkm", "decisionService"].contains(kind) {
    raise @types.fail("E_TCK_CASE_UNSUPPORTED", kind)
  }
  let invocable = case.attr("invocableName")
  let inputs = Map([])
  for input in case.all("inputNode") {
    @model.bind_input(
      inputs,
      input.attr("name"),
      value(input),
      model_namespace=input.attr("namespace"),
    )
  }
  let results = case.all("resultNode")
  if results.is_empty() {
    raise @types.fail("E_TCK_RESULT", "no result nodes")
  }
  for result in results {
    let actual = Ok(case_value(model, kind, invocable, result, inputs, clock)) catch {
      e => Err(e)
    }
    if result.attr_is_true("errorResult") {
      // Unsupported implementation paths must never satisfy an expected semantic error.
      // A null result is also accepted when the expected node is null: FEEL defines
      // many invalid operations (division by zero, bad argument types) as null.
      let expects_null = try {
        match result.child("expected") {
          Some(n) => value(n) is Null
          None => true
        }
      } catch {
        _ => false
      }
      match actual {
        Err(e) => if !semantic_error(error_code(e)) { raise e }
        Ok(v) =>
          if !(expects_null && v is Null) {
            raise @types.fail("E_TCK_EXPECTED_ERROR", "expected error")
          }
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
/// Run every TCK case beneath a directory and return a JSON report.
pub fn run(
  directory : String,
  clock~ : (() -> @types.DateTime)? = None,
) -> Json raise Error {
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
    let model : Result[@model.Model, Error] = Ok(@loader.load(model_path)) catch {
      e => Err(e)
    }
    let cases = root.all("testCase")
    if cases.is_empty() {
      infrastructure = infrastructure + 1
    }
    for case in cases {
      total = total + 1
      let mut detail = ""
      let outcome = try {
        match model {
          Ok(m) => check_case(m, case, clock)
          Err(e) => raise e
        }
        "PASS"
      } catch {
        @types.Failure(code, _, _, message) => {
          detail = message
          code
        }
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
            ("detail", Json(detail)),
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
