///|
fn err(code : String, message : String) -> @types.EngineError {
  @types.fail(code, message)
}

///|
fn arity(
  name : String,
  xs : Array[@types.Value],
  low : Int32,
  high : Int32,
) -> Unit raise @types.EngineError {
  if xs.length() < low || (high >= 0 && xs.length() > high) {
    raise err(
      "E_ARITY",
      name + " called with " + xs.length().to_string() + " arguments",
    )
  }
}

///|
fn number(
  v : @types.Value,
  name : String,
) -> @types.Decimal raise @types.EngineError {
  match v {
    Number(n) => n
    _ => raise err("E_TYPE", name + " requires a number")
  }
}

///|
fn text(v : @types.Value, name : String) -> String raise @types.EngineError {
  match v {
    Text(s) => s
    List([one]) => text(one, name)
    _ => raise err("E_TYPE", name + " requires a string")
  }
}

///|
fn list(
  v : @types.Value,
  name : String,
) -> Array[@types.Value] raise @types.EngineError {
  ignore(name)
  match v {
    List(xs) => xs
    Null => raise err("E_TYPE", "expected list")
    _ => [v]
  }
}

///|
/// Aggregates accept either a single list or a variadic argument list.
fn aggregate_items(xs : Array[@types.Value]) -> Array[@types.Value] {
  if xs.length() == 1 {
    if xs[0] is List(items) {
      return items
    }
  }
  xs
}

///|
fn variadic(name : String) -> Bool {
  [
    "count", "min", "max", "sum", "mean", "median", "stddev", "mode", "product",
    "all", "any", "append", "concatenate",
  ].contains(name)
}

///|
fn context_of(
  v : @types.Value,
  name : String,
) -> Map[String, @types.Value] raise @types.EngineError {
  match v {
    Context(c) => c
    _ => raise err("E_TYPE", name + " requires a context")
  }
}

///|

///|
fn num(n : Int32) -> @types.Value {
  Number(@types.decimal_int(n))
}

///|
fn contains_value(items : Array[@types.Value], target : @types.Value) -> Bool {
  for item in items {
    if item.equals(target) {
      return true
    }
  }
  false
}

///|
fn index_of_value(
  v : @types.Value,
  name : String,
) -> Int32 raise @types.EngineError {
  let d = number(v, name).round(0)
  d.to_int() catch {
    _ => raise err("E_TYPE", name + " position out of range")
  }
}

///|
fn call_function(
  f : @types.FunctionValue,
  args : Array[@types.Value],
) -> @types.Value raise @types.EngineError {
  (f.callback)(args)
}

///|
/// Names recognised by the FEEL lexer and evaluator. Multi-word entries must
/// stay in this list so that names with spaces are tokenised as one unit.
let builtin_names : Array[String] = [
  "date", "time", "date and time", "duration", "years and months duration", "not",
  "decimal sep", "grouping sep", "number", "string", "string length", "upper case",
  "lower case", "substring", "substring before", "substring after", "contains", "starts with",
  "ends with", "matches", "replace", "split", "string join", "trim", "decimal", "floor",
  "ceiling", "round up", "round down", "round half up", "round half down", "abs",
  "modulo", "sqrt", "log", "exp", "odd", "even", "count", "min", "max", "sum", "mean",
  "median", "stddev", "mode", "product", "all", "any", "list contains", "sublist",
  "append", "concatenate", "insert before", "remove", "list replace", "reverse",
  "index of", "union", "distinct values", "flatten", "sort", "not", "get value",
  "get entries", "context put", "context merge", "context", "day of week", "day of year",
  "week of year", "month of year", "day of month", "year", "today", "now", "before",
  "after", "meets", "met by", "overlaps", "overlaps before", "overlaps after", "finishes",
  "finished by", "includes", "during", "starts", "started by", "coincides", "start included",
  "end included", "time offset", "weekday", "timezone", "is", "range",
]

///|
let lexical_names : Array[String] = {
  let out = builtin_names.copy()
  for name in builtin_names {
    for param in params(name) {
      if !out.contains(param) {
        out.push(param)
      }
    }
  }
  out
}

///|
/// Return an independent builtin name list; callers may append scoped names.
pub fn names() -> Array[String] {
  builtin_names.copy()
}

///|
/// Cached lexical vocabulary including multi-word named parameters.
pub fn lexer_names() -> Array[String] {
  lexical_names.copy()
}

///|
/// Test membership in the supported builtin name vocabulary.
pub fn has(name : String) -> Bool {
  builtin_names.contains(name)
}

///|
/// Parameter names used for named arguments and function values.
pub fn params(name : String) -> Array[String] {
  match name {
    "not" | "abs" => ["n"]
    "sqrt" | "exp" | "log" | "odd" | "even" => ["number"]
    "floor" | "ceiling" => ["n", "scale"]
    "string" | "string length" | "upper case" | "lower case" | "trim" =>
      ["string"]
    "day of week"
    | "day of year"
    | "week of year"
    | "month of year"
    | "day of month"
    | "year" => ["date"]
    "count"
    | "min"
    | "max"
    | "sum"
    | "mean"
    | "reverse"
    | "distinct values"
    | "flatten" => [name]
    "get entries" => ["m"]
    "duration" => ["from"]
    "date" => ["year", "month", "day"]
    "time" => ["hour", "minute", "second", "offset"]
    "median" | "stddev" | "product" | "mode" | "all" | "any" => ["list"]
    "date and time" => ["date", "time"]
    "years and months duration" => ["from", "to"]
    "number" => ["from", "grouping separator", "decimal separator"]
    "substring" => ["string", "start position", "length"]
    "substring before"
    | "substring after"
    | "contains"
    | "starts with"
    | "ends with" => ["string", "match"]
    "split" => ["string", "delimiter"]
    "list contains" | "index of" => ["list", "element"]
    "matches" => ["input", "pattern", "flags"]
    "replace" => ["input", "pattern", "replacement", "flags"]
    "string join" => ["list", "delimiter", "prefix", "suffix"]
    "decimal"
    | "round up"
    | "round down"
    | "round half up"
    | "round half down" => ["n", "scale"]
    "modulo" => ["dividend", "divisor"]
    "sublist" => ["list", "start position", "length"]
    "append" | "concatenate" => ["list"]
    "insert before" => ["list", "position", "newItem"]
    "list replace" => ["list", "position", "newItem"]
    "remove" => ["list", "position"]
    "sort" => ["list", "precedes"]
    "get value" => ["m", "key"]
    "is" => ["value1", "value2"]
    "range" => ["from"]
    "context put" => ["context", "key", "value"]
    "context merge" => ["contexts"]
    "context" => ["entries"]
    "before"
    | "after"
    | "meets"
    | "met by"
    | "overlaps"
    | "overlaps before"
    | "overlaps after"
    | "finishes"
    | "finished by"
    | "includes"
    | "during"
    | "starts"
    | "started by"
    | "coincides" => ["point1", "point2"]
    _ => []
  }
}

///|
/// Temporal constructors accept both the overload parameter names used by
/// DMN (from / year-month-day / date-time / hour-minute-second-offset).
fn temporal_call(
  name : String,
  args : Array[(String?, @types.Value)],
) -> @types.Value raise @types.EngineError {
  let positional : Array[@types.Value] = []
  let named : Array[(String, @types.Value)] = []
  for arg in args {
    match arg.0 {
      None => positional.push(arg.1)
      Some(key) => named.push((key, arg.1))
    }
  }
  if named.is_empty() {
    return call(name, positional)
  }
  let order = match name {
    "date" => ["year", "month", "day"]
    "time" => ["hour", "minute", "second", "offset"]
    _ => ["year", "month", "day", "hour", "minute", "second", "offset"]
  }
  let slots : Array[@types.Value?] = []
  for _ in order {
    slots.push(None)
  }
  let mut from : @types.Value? = None
  let mut date_part : @types.Value? = None
  let mut time_part : @types.Value? = None
  for entry in named {
    let key = entry.0
    let value = entry.1
    if key == "from" {
      from = Some(value)
    } else if key == "date" && name == "date and time" {
      date_part = Some(value)
    } else if key == "time" && name == "date and time" {
      time_part = Some(value)
    } else {
      let mut at = -1
      for i, param in order {
        if param == key {
          at = i
        }
      }
      if at < 0 {
        raise err("E_ARITY", "unknown parameter " + key + " for " + name)
      }
      if slots[at] is Some(_) {
        raise err("E_ARITY", "duplicate argument: " + key)
      }
      slots[at] = Some(value)
    }
  }
  match from {
    Some(v) => positional.push(v)
    None =>
      match date_part {
        Some(d) => {
          positional.push(d)
          if time_part is Some(t) {
            positional.push(t)
          }
        }
        None => {
          let mut gap = false
          for slot in slots {
            match slot {
              Some(v) => {
                if gap {
                  raise err("E_ARITY", "missing argument for " + name)
                }
                positional.push(v)
              }
              None => gap = true
            }
          }
        }
      }
  }
  call(name, positional)
}

///|
/// Bind named arguments; invalid signatures have the FEEL null result.
pub fn call_args(
  name : String,
  args : Array[(String?, @types.Value)],
) -> @types.Value raise @types.EngineError {
  bind_args(name, args) catch {
    @types.Failure("E_ARITY", _, _, _) => Null
    e => raise e
  }
}

///|
fn bind_args(
  name : String,
  args : Array[(String?, @types.Value)],
) -> @types.Value raise @types.EngineError {
  if name == "context put" &&
    args.iter().any(arg => arg.0 is Some("key") && !(arg.1 is Text(_))) {
    return Null
  }
  let named = args.iter().any(arg => arg.0 is Some(_))
  if named && args.iter().any(arg => arg.0 is None) {
    raise err("E_ARITY", "cannot mix named and positional arguments")
  }
  if name == "date" || name == "time" || name == "date and time" {
    return temporal_call(name, args)
  }
  let names = if (name == "floor" || name == "ceiling") &&
    named &&
    !args.iter().any(arg => arg.0 is Some("scale")) {
    ["n"]
  } else {
    params(name)
  }
  if names.is_empty() {
    let positional = []
    for arg in args {
      match arg.0 {
        None => positional.push(arg.1)
        Some(key) =>
          raise err("E_ARITY", name + " does not accept named argument " + key)
      }
    }
    return call(name, positional)
  }
  let slots : Array[@types.Value?] = []
  for _ in names {
    slots.push(None)
  }
  let extras : Array[@types.Value] = []
  let mut next = 0
  for arg in args {
    match arg.0 {
      None => {
        while next < slots.length() && slots[next] is Some(_) {
          next = next + 1
        }
        if next >= slots.length() {
          if variadic(name) {
            extras.push(arg.1)
          } else {
            raise err("E_ARITY", "too many arguments for " + name)
          }
        } else {
          slots[next] = Some(arg.1)
          next = next + 1
        }
      }
      Some(key) => {
        let mut at = -1
        for i, param in names {
          if param == key {
            at = i
          }
        }
        if at < 0 {
          let target = match key {
            "keys" => "key"
            "match" => if name == "list replace" { "position" } else { "" }
            _ => ""
          }
          for i, param in names {
            if target != "" && param == target {
              at = i
            }
          }
        }
        if at < 0 {
          raise err("E_ARITY", "unknown parameter " + key + " for " + name)
        }
        if slots[at] is Some(_) {
          raise err("E_ARITY", "duplicate argument: " + key)
        }
        slots[at] = Some(arg.1)
      }
    }
  }
  let positional = []
  let mut gap = false
  for slot in slots {
    match slot {
      Some(v) => {
        if gap {
          raise err("E_ARITY", "missing argument for " + name)
        }
        positional.push(v)
      }
      None => if named { positional.push(Null) } else { gap = true }
    }
  }
  for extra in extras {
    positional.push(extra)
  }
  call(name, positional)
}

///|
/// Positional builtin dispatch.
pub fn call(
  name : String,
  xs : Array[@types.Value],
) -> @types.Value raise @types.EngineError {
  dispatch(name, xs) catch {
    @types.Failure(code, _, _, _) as e =>
      if [
          "E_TYPE", "E_ARITY", "E_NUMBER", "E_DECIMAL_SYNTAX", "E_DATE", "E_TIME",
          "E_DURATION", "E_RANGE", "E_REGEX", "E_TEMPORAL", "E_ZONE_UNSUPPORTED",
          "E_PARSE", "E_DATE_INVALID", "E_TIME_INVALID", "E_DATETIME_INVALID", "E_DURATION_INVALID",
          "E_ZONE_RANGE", "E_ZONE_GAP", "E_ZONE_DATE_REQUIRED",
        ].contains(code) {
        Null
      } else {
        raise e
      }
  }
}

///|
fn dispatch(
  name : String,
  xs : Array[@types.Value],
) -> @types.Value raise @types.EngineError {
  match name {
    "date" => {
      arity(name, xs, 1, 3)
      if xs.length() > 1 {
        let year = index_of_value(xs[0], name)
        let month = index_of_value(xs[1], name)
        let day = if xs.length() > 2 { index_of_value(xs[2], name) } else { 1 }
        Date(@types.date_of(year, month, day))
      } else {
        match xs[0] {
          Date(_) => xs[0]
          DateTime(dt) => Date(dt.date)
          Text(s) => Date(@types.parse_date(s))
          _ => raise err("E_TYPE", "date requires a string or date and time")
        }
      }
    }
    "time" => {
      arity(name, xs, 1, 4)
      if xs.length() > 1 {
        let hour = index_of_value(xs[0], name)
        let minute = index_of_value(xs[1], name)
        let seconds = if xs.length() > 2 {
          number(xs[2], name)
        } else {
          @types.zero()
        }
        let second = seconds.floor().to_int()
        let nanos = @types.decimal_to_scaled(
          seconds.add(@types.decimal_int(second).negate()),
          9,
        ).to_int()
        let zone : @types.Zone = if xs.length() > 3 && !(xs[3] is Null) {
          match xs[3] {
            DaysSeconds(d) => {
              let total = d.total_nanos()
              let seconds = total / 1000000000N
              if seconds < -50400N ||
                seconds > 50400N ||
                total % 1000000000N != 0N {
                raise err(
                  "E_TIME_INVALID", "offset must be whole seconds within 14 hours",
                )
              }
              @types.Fixed(seconds.to_int())
            }
            Text(s) => {
              let (z, _) = @types.parse_offset_text(s, 0)
              z
            }
            _ => raise err("E_TYPE", "time offset must be a duration")
          }
        } else {
          @types.Unzoned
        }
        Time(@types.make_time(hour, minute, second, nanos, zone))
      } else {
        match xs[0] {
          Time(_) => xs[0]
          DateTime(dt) => Time(dt.time)
          Date(_) => Time(@types.make_time(0, 0, 0, 0, @types.Fixed(0)))
          Text(s) => Time(@types.parse_time(s))
          _ => raise err("E_TYPE", "time requires a string or date and time")
        }
      }
    }
    "date and time" => {
      arity(name, xs, 1, 7)
      if xs.length() == 2 {
        let date = date_value(xs[0], name)
        let time = time_value(xs[1], name)
        @types.DateTime(@types.datetime_of(date, time))
      } else if xs.length() > 2 {
        let year = index_of_value(xs[0], name)
        let month = index_of_value(xs[1], name)
        let day = index_of_value(xs[2], name)
        let hour = if xs.length() > 3 { index_of_value(xs[3], name) } else { 0 }
        let minute = if xs.length() > 4 {
          index_of_value(xs[4], name)
        } else {
          0
        }
        let seconds = if xs.length() > 5 {
          number(xs[5], name)
        } else {
          @types.zero()
        }
        let second = seconds.floor().to_int()
        let nanos = @types.decimal_to_scaled(
          seconds.add(@types.decimal_int(second).negate()),
          9,
        ).to_int()
        @types.DateTime({
          date: @types.date_of(year, month, day),
          time: @types.make_time(hour, minute, second, nanos, @types.Unzoned),
        })
      } else {
        match xs[0] {
          DateTime(_) => xs[0]
          Date(d) =>
            @types.DateTime({
              date: d,
              time: @types.make_time(0, 0, 0, 0, @types.Unzoned),
            })
          Text(s) => {
            let datetime = if s.contains("T") {
              @types.parse_datetime(s)
            } else {
              let date = @types.parse_date(s)
              let time = @types.make_time(0, 0, 0, 0, @types.Unzoned)
              { date, time, }
            }
            @types.DateTime(datetime)
          }
          _ =>
            raise err("E_TYPE", "date and time requires a string or components")
        }
      }
    }
    "duration" => {
      arity(name, xs, 1, 1)
      let value = text(xs[0], name)
      let (days, months) = @types.parse_duration(value)
      if has_year_month(value) {
        YearsMonths(months)
      } else {
        DaysSeconds(days)
      }
    }
    "years and months duration" => {
      arity(name, xs, 2, 2)
      let from = date_value(xs[0], name)
      let to = date_value(xs[1], name)
      ym_between(from, to)
    }
    "number" => {
      arity(name, xs, 1, 3)
      match xs[0] {
        Text(s) => {
          if xs.length() == 3 &&
            !(xs[1] is Null) &&
            !(xs[2] is Null) &&
            xs[1].equals(xs[2]) {
            return Null
          }
          let mut body = s
          if xs.length() > 1 {
            let grouping = if xs[1] is Null { "" } else { text(xs[1], name) }
            if !["", ".", ",", " "].contains(grouping) {
              return Null
            }
            if grouping != "" {
              body = body.replace_all(old=grouping, new="")
            }
          }
          if xs.length() > 2 {
            let decimal_sep = if xs[2] is Null {
              "."
            } else {
              text(xs[2], name)
            }
            if ![".", ","].contains(decimal_sep) {
              return Null
            }
            if decimal_sep != "" && decimal_sep != "." {
              body = body.replace_all(old=decimal_sep, new=".")
            }
          }
          Number(@types.decimal(body))
        }
        _ => raise err("E_TYPE", "number requires a string")
      }
    }
    "not" => {
      arity(name, xs, 1, 1)
      match xs[0] {
        Boolean(b) => Boolean(!b)
        Null => Null
        _ => raise err("E_TYPE", "not requires a boolean")
      }
    }
    "string" => {
      arity(name, xs, 1, 1)
      match xs[0] {
        Null => Null
        _ => Text(xs[0].text())
      }
    }
    "string length" => {
      arity(name, xs, 1, 1)
      num(text(xs[0], name).char_length())
    }
    "upper case" => {
      arity(name, xs, 1, 1)
      Text(text(xs[0], name).to_upper())
    }
    "lower case" => {
      arity(name, xs, 1, 1)
      Text(text(xs[0], name).to_lower())
    }
    "trim" => {
      arity(name, xs, 1, 1)
      Text(text(xs[0], name).trim().to_owned())
    }
    "substring" => {
      arity(name, xs, 2, 3)
      let body = text(xs[0], name)
      let start = index_of_value(xs[1], name)
      let length = if xs.length() == 3 && !(xs[2] is Null) {
        Some(number(xs[2], name).floor().to_int())
      } else {
        None
      }
      substring_of(body, start, length)
    }
    "substring before" => {
      arity(name, xs, 2, 2)
      let body = text(xs[0], name)
      let needle = text(xs[1], name)
      match body.find(needle) {
        Some(at) => Text(String::from_array(body.to_array()[0:at]))
        None => Text("")
      }
    }
    "substring after" => {
      arity(name, xs, 2, 2)
      let body = text(xs[0], name)
      let needle = text(xs[1], name)
      match body.find(needle) {
        Some(at) => {
          let chars = body.to_array()
          let out = StringBuilder()
          let mut i = at + needle.char_length()
          while i < chars.length() {
            out.write_char(chars[i])
            i = i + 1
          }
          Text(out.to_string())
        }
        None => Text("")
      }
    }
    "contains" => {
      arity(name, xs, 2, 2)
      Boolean(text(xs[0], name).contains(text(xs[1], name)))
    }
    "starts with" => {
      arity(name, xs, 2, 2)
      Boolean(text(xs[0], name).has_prefix(text(xs[1], name)))
    }
    "ends with" => {
      arity(name, xs, 2, 2)
      Boolean(text(xs[0], name).has_suffix(text(xs[1], name)))
    }
    "matches" => {
      arity(name, xs, 2, 3)
      let input = text(xs[0], name)
      let pattern = text(xs[1], name)
      let flags = if xs.length() == 3 && !(xs[2] is Null) {
        text(xs[2], name)
      } else {
        ""
      }
      let regex = compile_regex(pattern, flags)
      Boolean(
        if flags.contains("m") {
          input
          .split("\n")
          .iter()
          .any(line => regex.execute(line.to_owned()) is Some(_))
        } else {
          regex.execute(input) is Some(_)
        },
      )
    }
    "replace" => {
      arity(name, xs, 3, 4)
      let input = text(xs[0], name)
      let pattern = text(xs[1], name)
      let replacement = text(xs[2], name)
      let flags = if xs.length() == 4 && !(xs[3] is Null) {
        text(xs[3], name)
      } else {
        ""
      }
      let regex = compile_regex(pattern, flags)
      Text(
        regex
        .replace_by(input, m => expand_replacement(replacement, m))
        .to_owned(),
      )
    }
    "split" => {
      arity(name, xs, 2, 2)
      let input = text(xs[0], name)
      let delimiter = text(xs[1], name)
      if delimiter == "" {
        List(input.to_array().map(ch => Text(ch.to_string())))
      } else {
        List(
          compile_regex(delimiter, "")
          .split(input)
          .to_array()
          .map(part => Text(part.to_owned())),
        )
      }
    }
    "string join" => {
      arity(name, xs, 1, 4)
      let items = list(xs[0], name)
      let delimiter = if xs.length() > 1 && !(xs[1] is Null) {
        text(xs[1], name)
      } else {
        ""
      }
      if xs.length() == 3 {
        return Null
      }
      let prefix = if xs.length() > 2 && !(xs[2] is Null) {
        text(xs[2], name)
      } else {
        ""
      }
      let suffix = if xs.length() > 3 && !(xs[3] is Null) {
        text(xs[3], name)
      } else {
        ""
      }
      let parts = []
      for item in items {
        if !(item is Null) {
          parts.push(text(item, name))
        }
      }
      Text(prefix + parts.join(delimiter) + suffix)
    }
    "decimal" => {
      arity(name, xs, 1, 2)
      let n = number(xs[0], name)
      if xs.length() == 2 {
        Number(n.round(index_of_value(xs[1], name)))
      } else {
        Number(n)
      }
    }
    "floor" => {
      arity(name, xs, 1, 2)
      if xs.length() > 1 && xs[1] is Null {
        return Null
      }
      let scale = if xs.length() > 1 && !(xs[1] is Null) {
        index_of_value(xs[1], name)
      } else {
        0
      }
      let factor = @types.Decimal::power_of_ten(
        if scale < 0 {
          -scale
        } else {
          scale
        },
      )
      let n = number(xs[0], name)
      Number(
        if scale < 0 {
          n.divide(factor).floor().multiply(factor)
        } else {
          n.multiply(factor).floor().divide(factor)
        },
      )
    }
    "ceiling" => {
      arity(name, xs, 1, 2)
      if xs.length() > 1 && xs[1] is Null {
        return Null
      }
      let scale = if xs.length() > 1 && !(xs[1] is Null) {
        index_of_value(xs[1], name)
      } else {
        0
      }
      let factor = @types.Decimal::power_of_ten(
        if scale < 0 {
          -scale
        } else {
          scale
        },
      )
      let n = number(xs[0], name)
      Number(
        if scale < 0 {
          n.divide(factor).ceiling().multiply(factor)
        } else {
          n.multiply(factor).ceiling().divide(factor)
        },
      )
    }
    "round up" | "round down" | "round half up" | "round half down" => {
      arity(name, xs, 2, 2)
      let n = number(xs[0], name)
      let scale = index_of_value(xs[1], name)
      Number(round_to(n, scale, name))
    }
    "abs" => {
      arity(name, xs, 1, 1)
      match xs[0] {
        DaysSeconds(d) => DaysSeconds(if d.negative { d.negate() } else { d })
        YearsMonths(d) =>
          YearsMonths(@types.DurationYM::canonical(false, d.years, d.months))
        _ => Number(number(xs[0], name).abs())
      }
    }
    "modulo" => {
      arity(name, xs, 2, 2)
      let divisor = number(xs[1], name)
      if divisor.is_zero() {
        Null
      } else {
        Number(number(xs[0], name).modulo(divisor))
      }
    }
    "sqrt" => {
      arity(name, xs, 1, 1)
      Number(number(xs[0], name).sqrt())
    }
    "log" => {
      arity(name, xs, 1, 1)
      Number(number(xs[0], name).ln())
    }
    "exp" => {
      arity(name, xs, 1, 1)
      Number(number(xs[0], name).exp())
    }
    "odd" => {
      arity(name, xs, 1, 1)
      let n = number(xs[0], name)
      Boolean(!n.modulo(@types.decimal_int(2)).is_zero())
    }
    "even" => {
      arity(name, xs, 1, 1)
      let n = number(xs[0], name)
      Boolean(n.modulo(@types.decimal_int(2)).is_zero())
    }
    "count" => {
      arity(name, xs, 1, -1)
      num(aggregate_items(xs).length())
    }
    "sum" | "mean" | "median" | "stddev" | "product" =>
      numeric_aggregate(name, xs)
    "min" | "max" => extremum(name, xs)
    "mode" => mode(xs)
    "all" | "any" => quantify_builtin(name, xs)
    "list contains" => {
      arity(name, xs, 2, 2)
      Boolean(list(xs[0], name).iter().any(item => item.equals(xs[1])))
    }
    "sublist" => {
      arity(name, xs, 2, 3)
      let items = list(xs[0], name)
      let start = index_of_value(xs[1], name)
      let length = if xs.length() == 3 && !(xs[2] is Null) {
        Some(index_of_value(xs[2], name))
      } else {
        None
      }
      List(sublist_of(items, start, length))
    }
    "append" => {
      arity(name, xs, 1, -1)
      let out = list(xs[0], name).copy()
      for i = 1; i < xs.length(); i = i + 1 {
        out.push(xs[i])
      }
      List(out)
    }
    "concatenate" => {
      arity(name, xs, 1, -1)
      let out = []
      for x in xs {
        out.append(list(x, name))
      }
      List(out)
    }
    "insert before" => {
      arity(name, xs, 3, 3)
      let items = list(xs[0], name).copy()
      let position = index_of_value(xs[1], name)
      if position < 1 || position > items.length() + 1 {
        raise err("E_RANGE", "insert position out of range")
      }
      items.insert(position - 1, xs[2])
      List(items)
    }
    "remove" => {
      arity(name, xs, 2, 2)
      let items = list(xs[0], name).copy()
      let position = index_of_value(xs[1], name)
      let at = if position < 0 {
        items.length() + position
      } else {
        position - 1
      }
      if at < 0 || at >= items.length() {
        raise err("E_RANGE", "remove position out of range")
      }
      ignore(items.remove(at))
      List(items)
    }
    "list replace" => {
      arity(name, xs, 3, 3)
      let items = match xs[0] {
        Null => raise err("E_TYPE", "list replace requires a list")
        List(inner) => inner.copy()
        single => [single]
      }
      match xs[1] {
        Function(f) => {
          if f.params.length() != 2 {
            raise err(
              "E_ARITY", "list replace match function requires two parameters",
            )
          }
          let out = []
          for item in items {
            let hit = call_function(f, [item, xs[2]])
            match hit {
              Boolean(true) => out.push(xs[2])
              Boolean(false) => out.push(item)
              _ =>
                raise err(
                  "E_TYPE", "list replace match function must return a boolean",
                )
            }
          }
          List(out)
        }
        Number(position) => {
          let n = position.truncate().to_int() catch {
              _ => raise err("E_TYPE", "list replace position out of range")
            }
          let at = if n < 0 { items.length() + n } else { n - 1 }
          if n == 0 || at < 0 || at >= items.length() {
            raise err("E_RANGE", "list replace position out of range")
          }
          items[at] = xs[2]
          List(items)
        }
        _ => raise err("E_TYPE", "list replace position must be a number")
      }
    }
    "reverse" => {
      arity(name, xs, 1, 1)
      List(list(xs[0], name).rev())
    }
    "index of" => {
      arity(name, xs, 2, 2)
      let items = list(xs[0], name)
      let out = []
      for i, item in items {
        if item.equals(xs[1]) {
          out.push(num(i + 1))
        }
      }
      List(out)
    }
    "union" => {
      arity(name, xs, 1, -1)
      let out = []
      for x in xs {
        for item in list(x, name) {
          if !contains_value(out, item) {
            out.push(item)
          }
        }
      }
      List(out)
    }
    "distinct values" => {
      arity(name, xs, 1, 1)
      let out = []
      for item in list(xs[0], name) {
        if !contains_value(out, item) {
          out.push(item)
        }
      }
      List(out)
    }
    "flatten" => {
      arity(name, xs, 1, 1)
      let out = []
      flatten_into(xs[0], out, 0)
      List(out)
    }
    "sort" => {
      arity(name, xs, 2, 2)
      let items = list(xs[0], name).copy()
      let compares = match xs[1] {
        Function(f) => f
        _ => raise err("E_TYPE", "sort requires a function")
      }
      insertion_sort(items, compares)
      List(items)
    }
    "get value" => {
      arity(name, xs, 2, 2)
      let ctx = context_of(xs[0], name)
      ctx.get(text(xs[1], name)).unwrap_or(Null)
    }
    "get entries" => {
      arity(name, xs, 1, 1)
      let ctx = context_of(xs[0], name)
      let keys = ctx.keys().to_array()
      keys.sort()
      List(keys.map(k => Context(Map([("key", Text(k)), ("value", ctx[k])]))))
    }
    "context put" => {
      arity(name, xs, 3, 3)
      let keys = match xs[1] {
        List(keys) => keys
        key => [key]
      }
      put_path(xs[0], keys, 0, xs[2])
    }
    "context merge" => {
      arity(name, xs, 1, 1)
      let out = Map([])
      for item in list(xs[0], name) {
        for k, v in context_of(item, name) {
          out[k] = v
        }
      }
      Context(out)
    }
    "context" => {
      arity(name, xs, 1, 1)
      let out = Map([])
      for entry in list(xs[0], name) {
        let ctx = context_of(entry, name)
        let key = text(ctx.get("key").unwrap_or(Null), name)
        if out.contains(key) || !ctx.contains("value") {
          raise err("E_TYPE", "duplicate key or missing value")
        }
        out[key] = ctx.get("value").unwrap_or(Null)
      }
      Context(out)
    }
    "day of week" => {
      arity(name, xs, 1, 1)
      Text(
        [
          "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
        ][date_value(xs[0], name).weekday() - 1],
      )
    }
    "day of year" => {
      arity(name, xs, 1, 1)
      num(date_value(xs[0], name).day_of_year())
    }
    "week of year" => {
      arity(name, xs, 1, 1)
      num(date_value(xs[0], name).week_of_year())
    }
    "month of year" => {
      arity(name, xs, 1, 1)
      Text(
        [
          "January", "February", "March", "April", "May", "June", "July", "August",
          "September", "October", "November", "December",
        ][date_value(xs[0], name).month - 1],
      )
    }
    "day of month" => {
      arity(name, xs, 1, 1)
      num(date_value(xs[0], name).day)
    }
    "year" => {
      arity(name, xs, 1, 1)
      num(date_value(xs[0], name).year)
    }
    "today" | "now" =>
      raise err(
        "E_BUILTIN_UNSUPPORTED",
        name + "() depends on the runtime clock and is not supported",
      )
    "before"
    | "after"
    | "meets"
    | "met by"
    | "overlaps"
    | "overlaps before"
    | "overlaps after"
    | "finishes"
    | "finished by"
    | "includes"
    | "during"
    | "starts"
    | "started by"
    | "coincides" => {
      arity(name, xs, 2, 2)
      Boolean(range_relation(name, xs[0], xs[1]))
    }
    "is" => {
      arity(name, xs, 2, 2)
      Boolean(
        match (xs[0], xs[1]) {
          (Time(a), Time(b)) => a.text() == b.text()
          (DateTime(a), DateTime(b)) => a.text() == b.text()
          _ => xs[0].equals(xs[1])
        },
      )
    }
    "range" => {
      arity(name, xs, 1, 1)
      parse_range_text(text(xs[0], name))
    }
    _ => raise err("E_BUILTIN_UNSUPPORTED", "unknown function: " + name)
  }
}

///|
fn temporal_literal(text : String) -> @types.Value raise @types.EngineError {
  if text.has_prefix("P") || text.has_prefix("-P") || text.has_prefix("+P") {
    let (days, months) = @types.parse_duration(text)
    if has_year_month(text) {
      YearsMonths(months)
    } else {
      DaysSeconds(days)
    }
  } else if text.contains("T") {
    DateTime(@types.parse_datetime(text))
  } else if text.contains(":") {
    Time(@types.parse_time(text))
  } else {
    Date(@types.parse_date(text))
  }
}

///|
fn range_endpoint(
  source : String,
  whole : String,
) -> @types.Value? raise @types.EngineError {
  let s = source.trim().to_owned()
  if s == "" {
    return None
  }
  let chars = s.to_array()
  if chars.length() >= 3 &&
    chars[0] == '@' &&
    chars[1] == '"' &&
    chars[chars.length() - 1] == '"' {
    let literal = String::from_array(chars[2:chars.length() - 1].to_owned())
    return Some(temporal_literal(literal))
  }
  if chars.length() >= 2 && chars[0] == '"' && chars[chars.length() - 1] == '"' {
    return Some(
      Text(String::from_array(chars[1:chars.length() - 1].to_owned())),
    )
  }
  for temporal_name in ["date", "date and time", "time", "duration"] {
    if s.has_prefix(temporal_name + "(") {
      match @parser.compile(s, names=[temporal_name]) {
        Call(Name(n), [arg]) =>
          match arg.value {
            Lit(Text(value)) => return Some(dispatch(n, [Text(value)]))
            _ =>
              raise err(
                "E_RANGE", "range constructor requires a string literal",
              )
          }
        _ => raise err("E_RANGE", "invalid range constructor")
      }
    }
  }
  if s == "true" {
    return Some(Boolean(true))
  }
  if s == "false" {
    return Some(Boolean(false))
  }
  if s == "null" {
    return Some(Null)
  }
  Some(Number(@types.decimal(s))) catch {
    _ => raise err("E_RANGE", "invalid range endpoint in " + whole)
  }
}

///|
fn parse_range_text(source : String) -> @types.Value raise @types.EngineError {
  let s = source.trim().to_owned()
  let chars = s.to_array()
  if chars.length() < 3 {
    raise err("E_RANGE", "invalid range: " + source)
  }
  let first = chars[0]
  let last = chars[chars.length() - 1]
  if (first != '[' && first != '(' && first != ']') ||
    (last != ']' && last != ')' && last != '[') {
    raise err("E_RANGE", "range must be enclosed in brackets: " + source)
  }
  let body = String::from_array(chars[1:chars.length() - 1].to_owned())
  let at = match body.find("..") {
    Some(i) => i
    None => raise err("E_RANGE", "range requires ..: " + source)
  }
  let body_chars = body.to_array()
  let start_text = String::from_array(body_chars[0:at].to_owned())
  let end_text = String::from_array(body_chars[at + 2:].to_owned())
  let start = range_endpoint(start_text, source)
  let end = range_endpoint(end_text, source)
  match (start, end) {
    (Some(a), Some(b)) =>
      if a is Null ||
        b is Null ||
        a.type_name() != b.type_name() ||
        @types.compare_values(a, b) > 0 {
        return Null
      }
    _ => return Null
  }
  Range({ start, start_included: first == '[', end, end_included: last == ']', })
}

///|
fn date_value(
  v : @types.Value,
  name : String,
) -> @types.Date raise @types.EngineError {
  match v {
    Date(d) => d
    DateTime(dt) => dt.date
    _ => raise err("E_TYPE", name + " requires a date")
  }
}

///|
fn time_value(
  v : @types.Value,
  name : String,
) -> @types.Time raise @types.EngineError {
  match v {
    Time(t) => t
    DateTime(dt) => dt.time
    Text(s) => @types.parse_time(s)
    _ => raise err("E_TYPE", name + " requires a time")
  }
}

///|
fn has_year_month(text : String) -> Bool {
  let chars = text.to_array()
  let mut i = 0
  if chars.length() > 0 && (chars[0] == '-' || chars[0] == '+') {
    i = 1
  }
  while i < chars.length() {
    if chars[i] == 'T' {
      return false
    }
    if chars[i] == 'Y' || chars[i] == 'M' {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn ym_between(
  from : @types.Date,
  to : @types.Date,
) -> @types.Value raise @types.EngineError {
  let raw = to.year.to_int64() * 12L +
    to.month.to_int64() -
    (from.year.to_int64() * 12L + from.month.to_int64())
  let months = raw +
    (if raw > 0L && to.day < from.day {
      -1L
    } else if raw < 0L && to.day > from.day {
      1L
    } else {
      0L
    })
  YearsMonths(@types.duration_ym_of_months(@bigint.BigInt::from_int64(months)))
}

///|
fn substring_of(body : String, start : Int32, length : Int32?) -> @types.Value {
  let chars = body.to_array()
  let n = chars.length()
  let begin = if start > 0 {
    start - 1
  } else if start == 0 {
    0
  } else {
    n + start
  }
  let begin = if begin < 0 { 0 } else if begin > n { n } else { begin }
  let finish = match length {
    Some(l) =>
      if l <= 0 {
        begin
      } else {
        let end = begin + l
        if end > n {
          n
        } else {
          end
        }
      }
    None => n
  }
  Text(String::from_array(chars[begin:finish].to_owned()))
}

///|
fn sublist_of(
  items : Array[@types.Value],
  start : Int32,
  length : Int32?,
) -> Array[@types.Value] {
  let n = items.length()
  let begin = if start > 0 {
    start - 1
  } else if start == 0 {
    0
  } else {
    n + start
  }
  let begin = if begin < 0 { 0 } else if begin > n { n } else { begin }
  let finish = match length {
    Some(l) =>
      if l <= 0 {
        begin
      } else {
        let end = begin + l
        if end > n {
          n
        } else {
          end
        }
      }
    None => n
  }
  items[begin:finish].to_owned()
}

///|
fn flatten_into(
  value : @types.Value,
  out : Array[@types.Value],
  depth : Int32,
) -> Unit raise @types.EngineError {
  if depth > 128 {
    raise err("E_LIMIT", "flatten nesting")
  }
  match value {
    List(xs) =>
      for x in xs {
        flatten_into(x, out, depth + 1)
      }
    _ => out.push(value)
  }
}

///|
fn numeric_aggregate(
  name : String,
  xs : Array[@types.Value],
) -> @types.Value raise @types.EngineError {
  arity(name, xs, 0, -1)
  let items = aggregate_items(xs)
  if items.is_empty() {
    return Null
  }
  if items.iter().any(item => item is Null) {
    return Null
  }
  if name == "product" {
    let mut acc = @types.decimal_int(1)
    for item in items {
      acc = acc.multiply(number(item, name))
    }
    return Number(acc)
  }
  let mut total = @types.zero()
  for item in items {
    total = total.add(number(item, name))
  }
  let count = @types.decimal_int(items.length())
  match name {
    "sum" => Number(total)
    "mean" => Number(total.divide(count))
    "median" => {
      let values = []
      for item in items {
        values.push(number(item, name))
      }
      values.sort_by((a, b) => a.compare(b))
      let n = values.length()
      if n % 2 == 1 {
        Number(values[n / 2])
      } else {
        Number(
          values[n / 2 - 1].add(values[n / 2]).divide(@types.decimal_int(2)),
        )
      }
    }
    "stddev" => {
      if items.length() < 2 {
        return Null
      }
      let mean = total.divide(count)
      let mut squares = @types.zero()
      for item in items {
        let diff = number(item, name).add(mean.negate())
        squares = squares.add(diff.multiply(diff))
      }
      let variance = squares.divide(@types.decimal_int(items.length() - 1))
      Number(variance.sqrt())
    }
    _ => raise err("E_BUILTIN_UNSUPPORTED", name)
  }
}

///|
fn extremum(
  name : String,
  xs : Array[@types.Value],
) -> @types.Value raise @types.EngineError {
  arity(name, xs, 0, -1)
  let items = aggregate_items(xs)
  if items.is_empty() {
    return Null
  }
  let mut best = items[0]
  for i = 1; i < items.length(); i = i + 1 {
    let c = @types.compare_values(items[i], best)
    if (name == "min" && c < 0) || (name == "max" && c > 0) {
      best = items[i]
    }
  }
  best
}

///|
fn same_kind(a : @types.Value, b : @types.Value) -> Bool {
  match (a, b) {
    (Number(_), Number(_))
    | (Text(_), Text(_))
    | (Boolean(_), Boolean(_))
    | (Date(_), Date(_))
    | (Time(_), Time(_))
    | (DateTime(_), DateTime(_))
    | (DaysSeconds(_), DaysSeconds(_))
    | (YearsMonths(_), YearsMonths(_)) => true
    _ => false
  }
}

///|
fn sort_values(items : Array[@types.Value]) -> Unit raise @types.EngineError {
  for i = 1; i < items.length(); i = i + 1 {
    let value = items[i]
    let mut j = i
    while j > 0 && @types.compare_values(items[j - 1], value) > 0 {
      items[j] = items[j - 1]
      j = j - 1
    }
    items[j] = value
  }
}

///|
fn mode(xs : Array[@types.Value]) -> @types.Value raise @types.EngineError {
  arity("mode", xs, 0, -1)
  if xs.is_empty() {
    return Null
  }
  let items = aggregate_items(xs)
  if items.is_empty() {
    return List([])
  }
  if items.iter().any(item => item is Null) {
    return Null
  }
  let first = items[0]
  if items.iter().any(item => !same_kind(first, item)) {
    return Null
  }
  let counts : Array[(Int32, @types.Value)] = []
  for item in items {
    let mut found = false
    for group in counts {
      if group.1.equals(item) {
        found = true
      }
    }
    if !found {
      let mut n = 0
      for other in items {
        if other.equals(item) {
          n = n + 1
        }
      }
      counts.push((n, item))
    }
  }
  let mut best = 0
  for group in counts {
    if group.0 > best {
      best = group.0
    }
  }
  let out = []
  for group in counts {
    if group.0 == best {
      out.push(group.1)
    }
  }
  sort_values(out)
  List(out)
}

///|
fn quantify_builtin(
  name : String,
  xs : Array[@types.Value],
) -> @types.Value raise @types.EngineError {
  arity(name, xs, 0, -1)
  if xs.is_empty() {
    return Null
  }
  let items = aggregate_items(xs)
  let mut unknown = false
  for item in items {
    match item {
      Boolean(true) => if name == "any" { return Boolean(true) }
      Boolean(false) => if name == "all" { return Boolean(false) }
      _ => unknown = true
    }
  }
  if unknown {
    Null
  } else {
    Boolean(name == "all")
  }
}

///|
fn insertion_sort(
  items : Array[@types.Value],
  precedes : @types.FunctionValue,
) -> Unit raise @types.EngineError {
  for i = 1; i < items.length(); i = i + 1 {
    let value = items[i]
    let mut j = i
    while j > 0 {
      let order = call_function(precedes, [value, items[j - 1]])
      if order is Boolean(true) {
        items[j] = items[j - 1]
        j = j - 1
      } else if order is Boolean(false) {
        break
      } else {
        raise err("E_TYPE", "sort comparator must return a boolean")
      }
    }
    items[j] = value
  }
}

///|
/// Round half-to-even after scaling to an integer.
fn round_to(
  n : @types.Decimal,
  scale : Int32,
  mode : String,
) -> @types.Decimal raise @types.EngineError {
  if scale < -6111 || scale > 6176 {
    raise err("E_NUMBER", "rounding scale out of range")
  }
  if scale >= 0 && scale >= n.scale {
    return n
  }
  let magnitude = if scale < 0 { -scale } else { scale }
  let factor = @types.decimal_int(1).multiply(
    @types.Decimal::power_of_ten(magnitude),
  ) catch {
    _ => raise err("E_NUMBER", "rounding scale out of range")
  }
  let scaled = if scale < 0 { n.divide(factor) } else { n.multiply(factor) }
  let rounded = {
    let negative = scaled.is_negative()
    let abs = scaled.abs()
    let down = abs.floor()
    let frac = abs.add(down.negate())
    let half = @types.decimal("0.5")
    let c = frac.compare(half)
    let magnitude = match mode {
      "round down" => down
      "round up" =>
        if frac.is_zero() {
          down
        } else {
          down.add(@types.decimal_int(1))
        }
      "round half up" =>
        if c >= 0 {
          down.add(@types.decimal_int(1))
        } else {
          down
        }
      "round half down" =>
        if c > 0 {
          down.add(@types.decimal_int(1))
        } else {
          down
        }
      _ => raise err("E_INTERNAL", "unknown rounding mode")
    }
    if negative {
      magnitude.negate()
    } else {
      magnitude
    }
  }
  if scale < 0 {
    rounded.multiply(factor)
  } else {
    rounded.divide(factor)
  }
}

///|
fn translate_pattern(pattern : String) -> String {
  pattern
  .replace_all(old="\\d", new="[[:digit:]]")
  .replace_all(old="\\w", new="[[:alnum:]_]")
  .replace_all(old="\\s", new="[[:space:]]")
  .replace_all(old="\\D", new="[^[:digit:]]")
}

///|
fn compile_regex(
  pattern : String,
  flags : String,
) -> @string.Regex raise @types.EngineError {
  let raw = StringBuilder()
  let mut in_class = false
  let mut escaped = false
  for ch in pattern.to_array() {
    if flags.contains("x") &&
      !in_class &&
      (ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') {
      continue
    }
    raw.write_char(ch)
    if !escaped && ch == '[' {
      in_class = true
    }
    if !escaped && ch == ']' {
      in_class = false
    }
    escaped = !escaped && ch == '\\'
  }
  let normalized = raw
    .to_string()
    .replace_all(old="\\p{IsBasicLatin}", new="[\u0000-\u007F]")
  let out = StringBuilder()
  let mut escaped = false
  let mut in_class = false
  for ch in translate_pattern(normalized).to_array() {
    if escaped {
      out.write_char(ch)
      escaped = false
    } else if ch == '\\' {
      out.write_char(ch)
      escaped = true
    } else if ch == '[' {
      in_class = true
      out.write_char(ch)
    } else if ch == ']' {
      in_class = false
      out.write_char(ch)
    } else if flags.contains("x") &&
      !in_class &&
      (ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') {
      ()
    } else if ch == '.' && !in_class && !flags.contains("s") {
      out.write_string("[^\n\r]")
    } else {
      out.write_char(ch)
    }
  }
  let mut body = out.to_string()
  for ch in flags.to_array() {
    if ch == 'i' {
      body = "(?i:" + body + ")"
    } else if ch == 's' || ch == 'm' || ch == 'x' {
      ()
    } else {
      raise err("E_REGEX", "unknown regular expression flag: " + ch.to_string())
    }
  }
  @string.Regex::Regex(body) catch {
    _ => raise err("E_REGEX", "invalid regular expression: " + pattern)
  }
}

///|
fn expand_replacement(
  replacement : String,
  m : @string.MatchResult,
) -> StringView {
  let out = StringBuilder()
  let chars = replacement.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '$' &&
      i + 1 < chars.length() &&
      chars[i + 1] >= '0' &&
      chars[i + 1] <= '9' {
      let group = chars[i + 1].to_int() - 48
      match m.group(group) {
        Some(part) => out.write_stringview(part)
        None => ()
      }
      i = i + 2
    } else {
      out.write_char(chars[i])
      i = i + 1
    }
  }
  out.to_string()[:]
}

///|
/// Range relation functions over points and half-open intervals.
fn start_bound(v : @types.Value) -> (@types.Value?, Bool) {
  match v {
    Range(r) => (r.start, r.start_included)
    _ => (Some(v), true)
  }
}

///|
fn end_bound(v : @types.Value) -> (@types.Value?, Bool) {
  match v {
    Range(r) => (r.end, r.end_included)
    _ => (Some(v), true)
  }
}

///|
fn as_range(v : @types.Value) -> @types.Range {
  match v {
    Range(r) => r
    _ =>
      {
        start: Some(v),
        start_included: true,
        end: Some(v),
        end_included: true,
      }
  }
}

///|
fn bound_compare(
  a : @types.Value?,
  b : @types.Value?,
) -> Int32 raise @types.EngineError {
  match (a, b) {
    (Some(x), Some(y)) => @types.compare_values(x, y)
    (None, None) => 0
    (None, Some(_)) => -1
    (Some(_), None) => 1
  }
}

///|
fn range_relation(
  name : String,
  a : @types.Value,
  b : @types.Value,
) -> Bool raise @types.EngineError {
  let (a_start, a_start_included) = start_bound(a)
  let (a_end, a_end_included) = end_bound(a)
  let (b_start, b_start_included) = start_bound(b)
  let (b_end, b_end_included) = end_bound(b)
  match name {
    "before" => {
      let c = bound_compare(a_end, b_start)
      c < 0 || (c == 0 && (!a_end_included || !b_start_included))
    }
    "after" => range_relation("before", b, a)
    "meets" => {
      let c = bound_compare(a_end, b_start)
      c == 0 && a_end_included && b_start_included
    }
    "met by" => range_relation("meets", b, a)
    "overlaps" => @types.Range::overlaps(as_range(a), as_range(b))
    "overlaps before" => {
      let starts = bound_compare(a_start, b_start)
      let ends = bound_compare(a_end, b_end)
      (starts < 0 || (starts == 0 && a_start_included && !b_start_included)) &&
      (ends < 0 || (ends == 0 && (!a_end_included || b_end_included))) &&
      @types.Range::overlaps(as_range(a), as_range(b))
    }
    "overlaps after" => range_relation("overlaps before", b, a)
    "finishes" => {
      let ends = bound_compare(a_end, b_end)
      let starts = bound_compare(a_start, b_start)
      ends == 0 &&
      a_end_included == b_end_included &&
      (starts > 0 || (starts == 0 && (!a_start_included || b_start_included)))
    }
    "finished by" => range_relation("finishes", b, a)
    "includes" => {
      let starts = bound_compare(b_start, a_start)
      let ends = bound_compare(a_end, b_end)
      let start_ok = starts > 0 ||
        (starts == 0 && (a_start_included || !b_start_included))
      let end_ok = ends > 0 ||
        (ends == 0 && (a_end_included || !b_end_included))
      start_ok && end_ok
    }
    "during" => range_relation("includes", b, a)
    "starts" => {
      let starts = bound_compare(a_start, b_start)
      let ends = bound_compare(a_end, b_end)
      starts == 0 &&
      a_start_included == b_start_included &&
      (ends < 0 || (ends == 0 && (!a_end_included || b_end_included)))
    }
    "started by" => range_relation("starts", b, a)
    "coincides" =>
      bound_compare(a_start, b_start) == 0 &&
      bound_compare(a_end, b_end) == 0 &&
      a_start_included == b_start_included &&
      a_end_included == b_end_included
    _ => raise err("E_BUILTIN_UNSUPPORTED", name)
  }
}

///|
fn put_path(
  value : @types.Value,
  keys : Array[@types.Value],
  at : Int32,
  replacement : @types.Value,
) -> @types.Value raise @types.EngineError {
  if keys.is_empty() {
    raise err("E_TYPE", "empty context path")
  }
  let ctx = context_of(value, "context put").copy()
  let key = text(keys[at], "context put")
  ctx[key] = if at + 1 == keys.length() {
    replacement
  } else {
    put_path(
      ctx.get(key).unwrap_or(Context(Map([]))),
      keys,
      at + 1,
      replacement,
    )
  }
  Context(ctx)
}
