// JavaScript-facing API for the browser playground.
//
// Every export takes one JSON string and returns one JSON string. Failures are
// reported as `{"ok":false,"error":{...}}`; nothing here throws. The package
// depends on the engine packages only, so the JS bundle has no file-system
// imports.

///|
fn obj(fields : Array[(String, Json)]) -> Json {
  let m : Map[String, Json] = Map([])
  for pair in fields {
    m[pair.0] = pair.1
  }
  Json::object(m)
}

///|
fn int_json(value : Int32) -> Json {
  Json::number(value.to_double())
}

///|
fn error_json(
  code : String,
  message : String,
  line : Int32,
  column : Int32,
) -> Json {
  obj([
    ("code", Json::string(code)),
    ("message", Json::string(message)),
    ("line", int_json(line)),
    ("column", int_json(column)),
  ])
}

///|
fn bad_request(message : String) -> @types.EngineError {
  @types.fail("E_REQUEST", message)
}

///|
fn failure_json(failure : Error) -> Json {
  let detail = match failure {
    @types.Failure(code, line, column, message) =>
      error_json(code, message, line, column)
    _ => error_json("E_INTERNAL", "unexpected error", 0, 0)
  }
  obj([("ok", Json::boolean(false)), ("error", detail)])
}

///|
fn respond(body : () -> Json raise Error) -> String {
  let result = body() catch { e => failure_json(e) }
  result.stringify()
}

///|
fn parse_request(text : String) -> Map[String, Json] raise Error {
  let parsed = @json.parse(text) catch {
    _ => raise bad_request("body is not valid JSON")
  }
  match parsed {
    Object(m) => m
    _ => raise bad_request("body must be a JSON object")
  }
}

///|
fn string_field(req : Map[String, Json], name : String) -> String raise Error {
  match req.get(name) {
    Some(String(s)) => s
    _ => raise bad_request("missing string field '" + name + "'")
  }
}

///|
/// Accepts a JSON object or a string holding JSON text, so callers can keep
/// exact decimal digits by sending the text.
fn object_text(req : Map[String, Json], name : String) -> String raise Error {
  match req.get(name) {
    None | Some(Null) => "{}"
    Some(String(text)) => if text.trim() == "" { "{}" } else { text }
    Some(Object(_) as value) => value.stringify()
    _ => raise bad_request("'" + name + "' must be an object")
  }
}

///|
fn clock_field(req : Map[String, Json]) -> (() -> @types.DateTime)? raise Error {
  match req.get("now") {
    Some(String(text)) if text.trim() != "" => {
      let fixed = @types.parse_datetime(text.trim().to_owned())
      Some(fn() { fixed })
    }
    _ => None
  }
}

///|
fn json_or_null(value : @types.Value) -> Json {
  value.json() catch {
    _ => Json::null()
  }
}

///|
fn value_json(value : @types.Value) -> Json {
  obj([
    ("value", json_or_null(value)),
    ("type", Json::string(value.type_name())),
    ("text", Json::string(value.text())),
  ])
}

///|
fn merge(base : Json, extra : Array[(String, Json)]) -> Json {
  match base {
    Object(m) => {
      for pair in extra {
        m[pair.0] = pair.1
      }
      Json::object(m)
    }
    other => other
  }
}

///|
/// Request: `{expression, context?, now?}`; `context` is an object or JSON text.
/// Response: `{"ok":true,"value":<json>,"type":"number","text":"..."}`.
pub fn feel_eval(request : String) -> String {
  respond(fn() raise Error {
    let req = parse_request(request)
    let source = string_field(req, "expression")
    let scope = @eval.with_clock(
      @types.json_context(object_text(req, "context")),
      clock_field(req),
    )
    let value = @eval.feel_eval(source, ctx=scope)
    merge(value_json(value), [("ok", Json::boolean(true))])
  })
}

///|
/// Request: `{xml}`.
/// Response: `{"ok":true,"name","namespace","inputs","decisions","knowledge",
/// "itemDefinitions","edges"}`; see `summary` below.
pub fn parse_dmn(request : String) -> String {
  respond(fn() raise Error {
    let req = parse_request(request)
    let model = @model.parse_model(string_field(req, "xml"))
    summary(model)
  })
}

///|
/// Request: `{xml}`. Response: `{"ok":true,"findings":[{code,decision,message,line,column}]}`.
pub fn lint(request : String) -> String {
  respond(fn() raise Error {
    let req = parse_request(request)
    let model = @model.parse_model(string_field(req, "xml"))
    obj([("ok", Json::boolean(true)), ("findings", @model.lint(model))])
  })
}

///|
/// Request: `{xml, decision, input?, now?}`.
/// Response: `{"ok":true,"value","type","text","values":{decision:json},"tables":{decision:{"hitPolicy","hits":[rule index]}}}`.
/// A failing evaluation still reports `tables` next to the error, so a
/// multiple-hit failure shows which rules matched.
pub fn evaluate(request : String) -> String {
  respond(fn() raise Error {
    let req = parse_request(request)
    let xml = string_field(req, "xml")
    let name = string_field(req, "decision")
    let model = @model.parse_model(xml)
    let input_text = object_text(req, "input")
    let clock = clock_field(req)
    let supplied = @model.json_inputs(model, input_text)
    let scope = fn() { @eval.with_clock(supplied.copy(), clock) }
    let closure = dependency_closure(model, name, supplied)
    let values : Map[String, Json] = Map([])
    for dependency in closure {
      if dependency != name {
        let value = @model.evaluate_decision(model, dependency, scope()) catch {
          _ => continue
        }
        values[dependency] = json_or_null(value)
      }
    }
    let tables = table_hits(xml, model, closure, scope)
    let outcome = @model.evaluate_decision(model, name, scope()) catch {
      e => return merge(failure_json(e), [("tables", tables)])
    }
    values[name] = json_or_null(outcome)
    merge(value_json(outcome), [
      ("ok", Json::boolean(true)),
      ("values", Json::object(values)),
      ("tables", tables),
    ])
  })
}
