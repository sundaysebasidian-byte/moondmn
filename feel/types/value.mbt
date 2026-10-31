///|
pub(all) enum Value {
  Null
  Boolean(Bool)
  Number(Decimal)
  Text(String)
  List(Array[Value])
  Context(Map[String, Value])
} derive(Eq)

///|
pub extend Value with Eq::{equal, not_equal}

///|
pub fn Value::json(self : Value) -> Json raise EngineError {
  match self {
    Null => Json::null()
    Boolean(b) => Json(b)
    Number(n) =>
      @json.parse(n.text(), preserve_number_repr=true) catch {
        _ => raise fail("E_INTERNAL", "decimal JSON")
      }
    Text(s) => Json(s)
    List(xs) => Json::array(xs.map(x => x.json()))
    Context(xs) => {
      let out = Map([])
      for k, v in xs {
        out[k] = v.json()
      }
      Json::object(out)
    }
  }
}

///|
pub fn from_json(j : Json) -> Value raise EngineError {
  match j {
    Null => Null
    True => Boolean(true)
    False => Boolean(false)
    Number(_, ..) => Number(decimal(j.stringify()))
    String(s) => Text(s)
    Array(xs) => List(xs.map(from_json))
    Object(xs) => {
      let out = Map([])
      for k, v in xs {
        out[k] = from_json(v)
      }
      Context(out)
    }
  }
}

///|
pub fn json_context(text : String) -> Map[String, Value] raise EngineError {
  let j = @json.parse(
    text,
    preserve_number_repr=true,
    reject_duplicate_keys=true,
  ) catch {
    _ => raise fail("E_JSON", "invalid JSON input")
  }
  match from_json(j) {
    Context(ctx) => ctx
    _ => raise fail("E_INPUT_TYPE", "context must be a JSON object")
  }
}
