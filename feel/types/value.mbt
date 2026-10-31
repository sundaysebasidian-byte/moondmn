///|
/// Runtime FEEL value. All temporal values are exact; functions capture their
/// defining scope in `callback`, which keeps the core value type independent
/// of the evaluator package.
pub(all) enum Value {
  Null
  Boolean(Bool)
  Number(Decimal)
  Text(String)
  Date(Date)
  Time(Time)
  DateTime(DateTime)
  DaysSeconds(DurationDS)
  YearsMonths(DurationYM)
  List(Array[Value])
  Context(Map[String, Value])
  Range(Range)
  Function(FunctionValue)
}

///|
/// Callable FEEL value with parameter names and a captured callback.
pub(all) struct FunctionValue {
  name : String
  params : Array[String]
  callback : (Array[Value]) -> Value raise EngineError
}

///|
/// Structural equality follows the FEEL `equals` rules, including temporal
/// instant comparison, so the `Eq` trait matches the rest of the engine.
pub impl Eq for Value with fn equal(self : Value, other : Value) {
  self.equals(other)
}

///|
pub extend Value with Eq::{not_equal, equal}

///|
/// Return the FEEL runtime type name.
pub fn Value::type_name(self : Value) -> String {
  match self {
    Null => "null"
    Boolean(_) => "boolean"
    Number(_) => "number"
    Text(_) => "string"
    Date(_) => "date"
    Time(_) => "time"
    DateTime(_) => "date and time"
    DaysSeconds(_) => "days and time duration"
    YearsMonths(_) => "years and months duration"
    List(_) => "list"
    Context(_) => "context"
    Range(_) => "range"
    Function(_) => "function"
  }
}

///|
/// Format a value as FEEL-oriented diagnostic text.
pub fn Value::text(self : Value) -> String {
  match self {
    Null => "null"
    Boolean(b) => b.to_string()
    Number(n) => n.text()
    Text(s) => s
    Date(d) => d.text()
    Time(t) => t.text()
    DateTime(d) => d.text()
    DaysSeconds(d) => d.text()
    YearsMonths(d) => d.text()
    List(xs) => "[" + xs.map(x => x.text()).join(", ") + "]"
    Context(xs) => {
      let keys = xs.keys().to_array()
      keys.sort()
      "{" +
      keys
      .map(k => {
        let body = match k.to_array() {
          [] => k
          [first, ..] =>
            if (first >= 'a' && first <= 'z') ||
              (first >= 'A' && first <= 'Z') ||
              first == '_' {
              k
            } else {
              "\"" + k + "\""
            }
        }
        body + ": " + xs[k].text()
      })
      .join(", ") +
      "}"
    }
    Range(r) => r.text()
    Function(f) => "function(" + f.params.join(", ") + ")"
  }
}

///|
fn time_compare(a : Time, b : Time) -> Int32 raise EngineError {
  match (a.zone, b.zone) {
    (Unzoned, Unzoned) => a.seconds().compare(b.seconds())
    (Unzoned, _) | (_, Unzoned) =>
      raise fail("E_TYPE", "cannot compare zoned and unzoned times")
    _ => {
      let ao = match standard_zone_offset(a.zone) {
        Some(o) => o
        None => raise fail("E_ZONE_UNSUPPORTED", "unknown time zone")
      }
      let bo = match standard_zone_offset(b.zone) {
        Some(o) => o
        None => raise fail("E_ZONE_UNSUPPORTED", "unknown time zone")
      }
      (a.seconds() - ao.to_int64() * 1000000000L).compare(
        b.seconds() - bo.to_int64() * 1000000000L,
      )
    }
  }
}

///|
fn datetime_compare(a : DateTime, b : DateTime) -> Int32 raise EngineError {
  match (a.has_offset(), b.has_offset()) {
    (true, true) => a.instant().compare(b.instant())
    (false, false) => {
      let c = a.date.ordinal().compare(b.date.ordinal())
      if c != 0 {
        c
      } else {
        time_compare(a.time, b.time)
      }
    }
    _ => raise fail("E_TYPE", "cannot compare zoned and unzoned date-times")
  }
}

///|
/// Compare compatible FEEL values; incompatible kinds raise E_TYPE.
pub fn compare_values(a : Value, b : Value) -> Int32 raise EngineError {
  match (a, b) {
    (Number(x), Number(y)) => x.compare(y)
    (Text(x), Text(y)) => if x < y { -1 } else if x > y { 1 } else { 0 }
    (Boolean(x), Boolean(y)) => if x == y { 0 } else if x { 1 } else { -1 }
    (Date(x), Date(y)) => x.ordinal().compare(y.ordinal())
    (Time(x), Time(y)) => time_compare(x, y)
    (DateTime(x), DateTime(y)) => datetime_compare(x, y)
    (DaysSeconds(x), DaysSeconds(y)) => x.total_nanos().compare(y.total_nanos())
    (YearsMonths(x), YearsMonths(y)) =>
      x.total_months().compare(y.total_months())
    (List(xs), List(ys)) => {
      let n = if xs.length() < ys.length() { xs.length() } else { ys.length() }
      for i = 0; i < n; i = i + 1 {
        let c = compare_values(xs[i], ys[i])
        if c != 0 {
          return c
        }
      }
      xs.length().compare(ys.length())
    }
    _ =>
      raise fail(
        "E_TYPE",
        "values of type " +
        a.type_name() +
        " and " +
        b.type_name() +
        " are not comparable",
      )
  }
}

///|
/// Compare FEEL values structurally, with temporal instant equality.
pub fn Value::equals(a : Value, b : Value) -> Bool {
  match (a, b) {
    (Null, Null) => true
    (Boolean(x), Boolean(y)) => x == y
    (Number(x), Number(y)) => x.compare(y) == 0
    (Text(x), Text(y)) => x == y
    (Date(x), Date(y)) =>
      x.year == y.year && x.month == y.month && x.day == y.day
    (Time(x), Time(y)) => time_equals(x, y)
    (DateTime(x), DateTime(y)) => datetime_equals(x, y)
    (DaysSeconds(x), DaysSeconds(y)) => x.total_nanos() == y.total_nanos()
    (YearsMonths(x), YearsMonths(y)) => x.total_months() == y.total_months()
    (List(xs), List(ys)) => {
      if xs.length() != ys.length() {
        return false
      }
      let mut same = true
      for i, x in xs {
        if !x.equals(ys[i]) {
          same = false
        }
      }
      same
    }
    (Context(xs), Context(ys)) => {
      if xs.length() != ys.length() {
        return false
      }
      let mut same = true
      for k, v in xs {
        match ys.get(k) {
          Some(w) => if !v.equals(w) { same = false }
          None => same = false
        }
      }
      same
    }
    (Range(x), Range(y)) =>
      x.start_included == y.start_included &&
      x.end_included == y.end_included &&
      eq_bound(x.start, y.start) &&
      eq_bound(x.end, y.end)
    _ => false
  }
}

///|
fn time_equals(x : Time, y : Time) -> Bool {
  if x.zone is Named(a) && y.zone is Named(b) && a == b {
    return x.seconds() == y.seconds()
  }
  let xs = x.seconds()
  let ys = y.seconds()
  match (standard_zone_offset(x.zone), standard_zone_offset(y.zone)) {
    (Some(a), Some(b)) =>
      xs - a.to_int64() * 1000000000L == ys - b.to_int64() * 1000000000L
    _ => false
  }
}

///|
fn datetime_instant_seconds(dt : DateTime) -> Int64? {
  let offset = datetime_zone_offset(dt) catch { _ => return None }
  Some(
    dt.date.ordinal() * 86400L +
    dt.time.seconds() / 1000000000L -
    offset.to_int64(),
  )
}

///|
fn datetime_equals(x : DateTime, y : DateTime) -> Bool {
  match (datetime_instant_seconds(x), datetime_instant_seconds(y)) {
    (Some(a), Some(b)) => a == b && x.time.nanos == y.time.nanos
    _ => false
  }
}

///|
fn eq_bound(a : Value?, b : Value?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(x), Some(y)) => x.equals(y)
    _ => false
  }
}

///|
/// Encode a value as JSON; decimals retain exact numeric spelling.
pub fn Value::json(self : Value) -> Json raise EngineError {
  match self {
    Null => Json::null()
    Boolean(b) => Json(b)
    Number(n) =>
      @json.parse(n.text(), preserve_number_repr=true) catch {
        _ => raise fail("E_INTERNAL", "decimal JSON")
      }
    Text(s) => Json(s)
    Date(d) => Json(d.text())
    Time(t) => Json(t.text())
    DateTime(d) => Json(d.text())
    DaysSeconds(d) => Json(d.text())
    YearsMonths(d) => Json(d.text())
    List(xs) => Json::array(xs.map(x => x.json()))
    Context(xs) => {
      let out = Map([])
      for k, v in xs {
        out[k] = v.json()
      }
      Json::object(out)
    }
    Range(r) => r.json()
    Function(_) => Json::null()
  }
}

///|
/// Decode JSON values using exact decimals.
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
/// Decode a JSON object, rejecting invalid JSON and duplicate keys.
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
