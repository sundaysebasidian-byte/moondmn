///|
/// Validate caller-built trees before recursive evaluation.
pub fn evaluate(
  expr : @parser.Expr,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  @parser.validate(expr)
  evaluate_inner(expr, ctx)
}

///|
fn scope_with(
  ctx : Map[String, @types.Value],
  name : String,
  value : @types.Value,
) -> Map[String, @types.Value] {
  let scope = ctx.copy()
  scope[name] = value
  scope
}

///|
fn err(code : String, message : String) -> @types.EngineError {
  @types.fail(code, message)
}

///|
/// Evaluate a compiled expression in the supplied scope.
fn evaluate_inner(
  expr : @parser.Expr,
  ctx : Map[String, @types.Value],
  depth~ : Int32 = 0,
) -> @types.Value raise @types.EngineError {
  if depth > 128 {
    raise err("E_LIMIT", "evaluation nesting exceeds 128")
  }
  match expr {
    External(descriptor) =>
      invoke_external(evaluate_inner(descriptor, ctx, depth=depth + 1), [], ctx)
    Lit(v) => v
    Name(n) =>
      match ctx.get(n) {
        Some(v) => v
        None =>
          if @builtins.has(n) {
            @types.Function({
              name: n,
              params: @builtins.params(n),
              callback: args => @builtins.call(n, args),
            })
          } else {
            raise err("E_NAME", "unknown name: " + n)
          }
      }
    Unary(op, e) => {
      let value = evaluate_inner(e, ctx, depth=depth + 1)
      match op {
        "=" | "!=" =>
          if value is Null {
            Null
          } else {
            Range({
              comparison: Some(op),
              start: Some(value),
              start_included: op == "=",
              end: Some(value),
              end_included: op == "=",
            })
          }
        "-" =>
          match value {
            Number(n) => Number(n.negate())
            DaysSeconds(d) => DaysSeconds(d.negate())
            YearsMonths(d) =>
              YearsMonths(
                @types.DurationYM::canonical(!d.negative, d.years, d.months),
              )
            Null => Null
            _ => raise err("E_TYPE", "unary minus requires a number")
          }
        "+" =>
          match value {
            Number(_) => value
            Null => Null
            _ => raise err("E_TYPE", "unary plus requires a number")
          }
        _ =>
          match value {
            Boolean(b) => Boolean(!b)
            Null => Null
            _ => raise err("E_TYPE", "not requires a boolean")
          }
      }
    }
    Binary(op, a, b) => {
      let left = evaluate_inner(a, ctx, depth=depth + 1)
      match op {
        "and" =>
          if left is Boolean(false) {
            Boolean(false)
          } else {
            let right = evaluate_inner(b, ctx, depth=depth + 1)
            if right is Boolean(false) {
              Boolean(false)
            } else if left is Boolean(true) && right is Boolean(true) {
              Boolean(true)
            } else {
              Null
            }
          }
        "or" =>
          if left is Boolean(true) {
            Boolean(true)
          } else {
            let right = evaluate_inner(b, ctx, depth=depth + 1)
            if right is Boolean(true) {
              Boolean(true)
            } else if left is Boolean(false) && right is Boolean(false) {
              Boolean(false)
            } else {
              Null
            }
          }
        _ => {
          let right = evaluate_inner(b, ctx, depth=depth + 1)
          binary(op, left, right) catch {
            @types.Failure("E_DECIMAL_RANGE" | "E_NUMBER", _, _, _) => Null
            e => raise e
          }
        }
      }
    }
    IfThenElse(c, a, b) =>
      match evaluate_inner(c, ctx, depth=depth + 1) {
        Boolean(true) => evaluate_inner(a, ctx, depth=depth + 1)
        Boolean(false) => evaluate_inner(b, ctx, depth=depth + 1)
        _ => evaluate_inner(b, ctx, depth=depth + 1)
      }
    ListLit(xs) => List(xs.map(x => evaluate_inner(x, ctx, depth=depth + 1)))
    ContextLit(entries) => {
      let scope = ctx.copy()
      let out = Map([])
      for pair in entries {
        if out.contains(pair.0) {
          return Null
        }
        let value = evaluate_inner(pair.1, scope, depth=depth + 1)
        scope[pair.0] = value
        out[pair.0] = value
      }
      Context(out)
    }
    RangeLit(start, start_included, end, end_included) => {
      let lower = match start {
        Some(e) => Some(evaluate_inner(e, ctx, depth=depth + 1))
        None => None
      }
      let upper = match end {
        Some(e) => Some(evaluate_inner(e, ctx, depth=depth + 1))
        None => None
      }
      if (lower is Some(l) && l is Null) || (upper is Some(u) && u is Null) {
        Null
      } else {
        if lower is Some(a) && upper is Some(b) {
          let order = @types.compare_values(a, b) catch { _ => return Null }
          if a.type_name() != b.type_name() || order > 0 {
            return Null
          }
        }
        @types.Range({
          comparison: None,
          start: lower,
          start_included,
          end: upper,
          end_included,
        })
      }
    }
    Seq(low, high) => {
      let from = evaluate_inner(low, ctx, depth=depth + 1)
      let to = evaluate_inner(high, ctx, depth=depth + 1)
      match sequence_items(from, to) {
        Some(items) => List(items)
        None => Null
      }
    }
    Path(value, name) => path(evaluate_inner(value, ctx, depth=depth + 1), name)
    Filter(value, filter) =>
      filter_value(evaluate_inner(value, ctx, depth=depth + 1), filter, ctx)
    Call(callee, args) => {
      let evaluated = args.map(a => {
        (a.name, evaluate_inner(a.value, ctx, depth=depth + 1))
      })
      match callee {
        Name(n) =>
          match ctx.get(n) {
            Some(Function(f)) => invoke(f, evaluated)
            Some(_) => raise err("E_TYPE", n + " is not a function")
            None =>
              if @builtins.has(n) {
                @builtins.call_args(n, evaluated)
              } else {
                Null
              }
          }
        _ =>
          match evaluate_inner(callee, ctx, depth=depth + 1) {
            Function(f) => invoke(f, evaluated)
            _ => raise err("E_TYPE", "call target is not a function")
          }
      }
    }
    For(bindings, body) =>
      match environments(bindings, 0, ctx, 0) {
        Some(envs) => {
          let out = []
          let needs_prefix = !prefix_free(body)
          for env in envs {
            let scope = env.copy()
            if needs_prefix {
              scope["partial"] = List(out.copy())
            }
            out.push(evaluate_inner(body, scope, depth=depth + 1))
          }
          List(out)
        }
        None => Null
      }
    SomeIn(bindings, body) =>
      match environments(bindings, 0, ctx, 0) {
        Some(envs) => quantify(envs, body, true)
        None => Null
      }
    EveryIn(bindings, body) =>
      match environments(bindings, 0, ctx, 0) {
        Some(envs) => quantify(envs, body, false)
        None => Null
      }
    FunctionDef(params, body) => {
      let captured = ctx.copy()
      @types.Function({
        name: "function",
        params,
        callback: args => {
          if args.length() != params.length() {
            raise err(
              "E_ARITY",
              "function expects " + params.length().to_string() + " arguments",
            )
          }
          let scope = captured.copy()
          for i, param in params {
            scope[param] = args[i]
          }
          if body is External(descriptor) {
            invoke_external(
              evaluate_inner(descriptor, scope, depth=depth + 1),
              args,
              captured,
            )
          } else {
            evaluate_inner(body, scope, depth=depth + 1)
          }
        },
      })
    }
    TypedFunctionDef(parameters, body) => {
      let captured = ctx.copy()
      Function({
        name: "function",
        params: parameters.map(p => p.0),
        callback: args => {
          if args.length() != parameters.length() {
            return Null
          }
          let scope = captured.copy()
          for i, parameter in parameters {
            let value = args[i]
            let name = parameter.1.trim().to_owned().to_lower()
            let value = if !(value is Null) &&
              !instance_of(value, parameter.1, captured) {
              if name == "list" || name.has_prefix("list<") {
                @types.List([value])
              } else {
                match value {
                  List([one]) => one
                  _ => value
                }
              }
            } else {
              value
            }
            let value = if (name == "date and time" || name == "datetime") &&
              value is Date(d) {
              @types.DateTime({
                date: d,
                time: @types.make_time(0, 0, 0, 0, @types.Fixed(0)),
              })
            } else {
              value
            }
            if !(value is Null) && !instance_of(value, parameter.1, captured) {
              return Null
            }
            scope[parameter.0] = value
          }
          if body is External(descriptor) {
            invoke_external(
              evaluate_inner(descriptor, scope, depth=depth + 1),
              parameters.map(p => scope[p.0]),
              captured,
            )
          } else {
            evaluate_inner(body, scope, depth=depth + 1)
          }
        },
      })
    }
    InstanceOf(value, type_name) =>
      Boolean(
        instance_of(evaluate_inner(value, ctx, depth=depth + 1), type_name, ctx),
      )
    Between(value, low, high) => {
      let x = evaluate_inner(value, ctx, depth=depth + 1)
      let l = evaluate_inner(low, ctx, depth=depth + 1)
      let h = evaluate_inner(high, ctx, depth=depth + 1)
      if x is Null || l is Null || h is Null {
        Null
      } else {
        Boolean(
          @types.compare_values(x, l) >= 0 && @types.compare_values(x, h) <= 0,
        )
      }
    }
    In(value, check) =>
      test_match_value(check, evaluate_inner(value, ctx, depth=depth + 1), ctx)
  }
}

///|
/// Invoke a FEEL function with named or positional arguments.
pub fn call_function(
  f : @types.FunctionValue,
  args : Array[(String?, @types.Value)],
) -> @types.Value raise @types.EngineError {
  invoke(f, args)
}

///|
fn invoke(
  f : @types.FunctionValue,
  args : Array[(String?, @types.Value)],
) -> @types.Value raise @types.EngineError {
  let slots : Array[@types.Value?] = []
  for _ in f.params {
    slots.push(None)
  }
  let named = args.iter().any(arg => arg.0 is Some(_))
  if named && args.iter().any(arg => arg.0 is None) {
    raise err("E_ARITY", "cannot mix named and positional arguments")
  }
  let mut next = 0
  for arg in args {
    match arg.0 {
      None => {
        while next < slots.length() && slots[next] is Some(_) {
          next = next + 1
        }
        if next >= slots.length() {
          raise err("E_ARITY", "too many arguments for " + f.name)
        }
        slots[next] = Some(arg.1)
        next = next + 1
      }
      Some(key) => {
        let mut index = -1
        for i, param in f.params {
          if param == key {
            index = i
          }
        }
        if index < 0 {
          raise err("E_ARITY", "unknown parameter: " + key)
        }
        if slots[index] is Some(_) {
          raise err("E_ARITY", "duplicate parameter: " + key)
        }
        slots[index] = Some(arg.1)
      }
    }
  }
  let bound = []
  for i, slot in slots {
    match slot {
      Some(v) => bound.push(v)
      None =>
        if named {
          bound.push(Null)
        } else {
          raise err(
            "E_ARITY",
            "missing argument " + f.params[i] + " for " + f.name,
          )
        }
    }
  }
  (f.callback)(bound)
}

///|
// Prove absence only in simple expressions. Calls, scopes and unary tests
// conservatively keep the existing snapshots, including captured closures.
fn prefix_free(body : @parser.Expr) -> Bool {
  match body {
    Lit(_) => true
    Name(name) => name != "partial"
    Unary(_, inner) => prefix_free(inner)
    Binary(_, left, right) => prefix_free(left) && prefix_free(right)
    IfThenElse(c, yes, no) =>
      prefix_free(c) && prefix_free(yes) && prefix_free(no)
    _ => false
  }
}

///|
/// Expand a numeric or date sequence `a..b`. Other endpoint kinds are not
/// iterable and yield `None` (the whole iterator produces null).
fn sequence_items(
  from : @types.Value,
  to : @types.Value,
) -> Array[@types.Value]? raise @types.EngineError {
  let out : Array[@types.Value] = []
  match (from, to) {
    (Number(a), Number(b)) => {
      let low = a.to_int()
      let high = b.to_int()
      let step = if low <= high { 1 } else { -1 }
      let mut at = low
      while true {
        out.push(Number(@types.decimal_int(at)))
        if out.length() > 100000 {
          raise err("E_LIMIT", "iteration produces too many values")
        }
        if at == high {
          break
        }
        at += step
      }
      Some(out)
    }
    (Date(a), Date(b)) => {
      let low = a.ordinal()
      let high = b.ordinal()
      let mut at = low
      while true {
        out.push(Date(@types.date_add_days(a, at - low)))
        if out.length() > 100000 {
          raise err("E_LIMIT", "iteration produces too many values")
        }
        if (low <= high && at >= high) || (low > high && at <= high) {
          break
        }
        at = at + (if low <= high { 1L } else { -1L })
      }
      Some(out)
    }
    _ => None
  }
}

///|
fn environments(
  bindings : Array[(String, @parser.Expr)],
  index : Int32,
  scope : Map[String, @types.Value],
  count : Int32,
) -> Array[Map[String, @types.Value]]? raise @types.EngineError {
  if index > 128 {
    raise err("E_LIMIT", "iteration binding nesting exceeds 128")
  }
  if count > 100000 {
    raise err("E_LIMIT", "iteration produces too many values")
  }
  if index >= bindings.length() {
    let copy = scope.copy()
    return Some([copy])
  }
  let pair = bindings[index]
  let items = match pair.1 {
    Seq(low, high) =>
      match
        sequence_items(evaluate_inner(low, scope), evaluate_inner(high, scope)) {
        Some(xs) => xs
        None => return None
      }
    RangeLit(_, _, _, _) => {
      // Bracketed intervals are values, never sequence domains (even if invalid).
      ignore(evaluate_inner(pair.1, scope))
      return None
    }
    _ => {
      let value = evaluate_inner(pair.1, scope)
      match value {
        List(xs) => xs
        Range(_) => return None
        _ => [value]
      }
    }
  }
  let out = []
  for item in items {
    let inner = scope.copy()
    inner[pair.0] = item
    match environments(bindings, index + 1, inner, count + out.length()) {
      Some(inner_envs) => out.append(inner_envs)
      None => return None
    }
  }
  Some(out)
}

///|
fn quantify(
  envs : Array[Map[String, @types.Value]],
  body : @parser.Expr,
  some : Bool,
) -> @types.Value raise @types.EngineError {
  let mut has_null = false
  for env in envs {
    match evaluate_inner(body, env) {
      Boolean(false) => if !some { return Boolean(false) }
      Boolean(true) => if some { return Boolean(true) }
      Null => has_null = true
      _ => raise err("E_TYPE", "quantifier requires booleans")
    }
  }
  if has_null {
    Null
  } else if some {
    Boolean(false)
  } else {
    Boolean(true)
  }
}

///|
fn generic_inner(name : String, prefix : String) -> String {
  // The caller has already checked the ASCII prefix case-insensitively.
  name[prefix.length():name.length() - 1].to_owned()
}

///|
fn context_type_fields(body : String) -> Array[String] {
  let chars = body.to_array()
  let fields = []
  let mut start = 0
  let mut nesting = 0
  for i, ch in chars {
    if ch == '<' {
      nesting += 1
    } else if ch == '>' && (i == 0 || chars[i - 1] != '-') {
      nesting -= 1
    } else if ch == ',' && nesting == 0 {
      fields.push(String::from_array(chars[start:i].to_owned()))
      start = i + 1
    }
  }
  fields.push(String::from_array(chars[start:].to_owned()))
  fields
}

///|
/// Count declared parameter slots, not the inner fields of a parameter type.
fn function_parameter_count(name : String) -> Int32 {
  let chars = name.to_array()
  let start = "function<".length()
  let mut depth = 0
  let mut count = 1
  for i in start..<chars.length() {
    let ch = chars[i]
    if ch == '<' {
      depth += 1
    } else if ch == '>' && chars[i - 1] != '-' {
      if depth == 0 {
        return if i == start { 0 } else { count }
      }
      depth -= 1
    } else if ch == ',' && depth == 0 {
      count += 1
    }
  }
  0
}

///|
fn instance_of(
  value : @types.Value,
  type_name : String,
  ctx : Map[String, @types.Value],
) -> Bool raise @types.EngineError {
  instance_of_at(value, type_name, ctx, 0)
}

///|
fn instance_of_at(
  value : @types.Value,
  type_name : String,
  ctx : Map[String, @types.Value],
  depth : Int32,
) -> Bool raise @types.EngineError {
  if depth > 32 {
    return false
  }
  let name = type_name.trim().to_owned()
  let lower = name.to_lower()
  if lower.has_prefix("list<") && name.has_suffix(">") {
    let inner = generic_inner(name, "list<")
    return match value {
      List(xs) => xs.iter().all(x => instance_of_at(x, inner, ctx, depth + 1))
      _ => false
    }
  }
  if lower.has_prefix("range<") && name.has_suffix(">") {
    let inner = generic_inner(name, "range<")
    return match value {
      Range(r) =>
        match (r.start, r.end) {
          (Some(a), Some(b)) =>
            instance_of_at(a, inner, ctx, depth + 1) &&
            instance_of_at(b, inner, ctx, depth + 1)
          (Some(a), None) => instance_of_at(a, inner, ctx, depth + 1)
          (None, Some(b)) => instance_of_at(b, inner, ctx, depth + 1)
          (None, None) => true
        }
      _ => false
    }
  }
  if lower.has_prefix("context<") && name.has_suffix(">") {
    let body = generic_inner(name, "context<")
    return match value {
      Context(entries) => {
        let mut ok = true
        for spec in context_type_fields(body) {
          match spec.find(":") {
            Some(at) => {
              let key = spec[:at].trim().to_owned()
              let ty = spec[at + 1:].trim().to_owned()
              match entries.get(key) {
                Some(v) =>
                  if !(v is Null) && !instance_of_at(v, ty, ctx, depth + 1) {
                    ok = false
                  }
                None => ok = false
              }
            }
            None => ok = false
          }
        }
        ok
      }
      _ => false
    }
  }
  if lower.contains("->") && lower.has_prefix("function") {
    let arity = if lower.has_prefix("function<") {
      function_parameter_count(name)
    } else {
      0
    }
    return match value {
      // Preserve legacy zero- and single-parameter descriptor behavior.
      Function(f) => arity <= 1 || f.params.length() == arity
      _ => false
    }
  }
  match lower {
    "number" => value is Number(_)
    "string" => value is Text(_)
    "boolean" => value is Boolean(_)
    "date" => value is Date(_)
    "time" => value is Time(_)
    "date and time" | "datetime" => value is DateTime(_)
    "days and time duration" | "daytimeduration" => value is DaysSeconds(_)
    "years and months duration" | "yearmonthduration" => value is YearsMonths(_)
    "duration" | "date and time duration" =>
      value is DaysSeconds(_) || value is YearsMonths(_)
    "list" => value is List(_)
    "context" => value is Context(_)
    "range" => value is Range(_)
    "function" => value is Function(_)
    "null" => value is Null
    "any" => !(value is Null)
    _ =>
      match ctx.get("$types") {
        Some(Context(types)) =>
          match types.get(name) {
            Some(Text(desc)) => instance_of_at(value, desc, ctx, depth + 1)
            _ => false
          }
        _ => false
      }
  }
}

///|
fn path(
  value : @types.Value,
  name : String,
) -> @types.Value raise @types.EngineError {
  match value {
    Null => Null
    Context(c) => c.get(name).unwrap_or(Null)
    List(xs) => List(xs.map(x => path(x, name)))
    Date(d) => date_property(d, name)
    Time(t) => time_property(t, name)
    DateTime(dt) =>
      match name {
        "time offset" =>
          if dt.time.zone is Unzoned {
            Null
          } else {
            DaysSeconds(
              @types.duration_ds_of_nanos(
                @bigint.BigInt::from_int(@types.datetime_zone_offset(dt)) *
                1000000000N,
              ),
            )
          }
        "date" => Date(dt.date)
        "time" => Time(dt.time)
        "year" => Number(@types.decimal_int(dt.date.year))
        "month" => Number(@types.decimal_int(dt.date.month))
        "day" => Number(@types.decimal_int(dt.date.day))
        "weekday" => Number(@types.decimal_int(dt.date.weekday()))
        _ => time_property(dt.time, name)
      }
    DaysSeconds(d) => duration_ds_property(d, name)
    YearsMonths(d) =>
      match name {
        "years" => Number(@types.decimal_int(signed_years(d)))
        "months" => Number(@types.decimal_int(signed_months(d)))
        _ => Null
      }
    Range(r) =>
      match name {
        "start" => r.start.unwrap_or(Null)
        "end" => r.end.unwrap_or(Null)
        "start included" => Boolean(r.start_included)
        "end included" => Boolean(r.end_included)
        _ => Null
      }
    _ => raise err("E_TYPE", "value has no property " + name)
  }
}

///|
fn date_property(date : @types.Date, name : String) -> @types.Value {
  match name {
    "year" => Number(@types.decimal_int(date.year))
    "month" => Number(@types.decimal_int(date.month))
    "day" => Number(@types.decimal_int(date.day))
    "weekday" => Number(@types.decimal_int(date.weekday()))
    _ => Null
  }
}

///|
fn time_property(
  time : @types.Time,
  name : String,
) -> @types.Value raise @types.EngineError {
  match name {
    "hour" => Number(@types.decimal_int(time.hour))
    "minute" => Number(@types.decimal_int(time.minute))
    "second" =>
      if time.nanos == 0 {
        Number(@types.decimal_int(time.second))
      } else {
        Number(
          @types.decimal(time.second.to_string() + "." + nanos_text(time.nanos)),
        )
      }
    "time offset" =>
      match time.zone {
        Fixed(seconds) =>
          DaysSeconds(
            @types.duration_ds_of_nanos(
              @bigint.BigInt::from_int(seconds) * 1000000000N,
            ),
          )
        _ => Null
      }
    "timezone" =>
      match time.zone {
        Named(z) => Text(z)
        _ => Null
      }
    _ => Null
  }
}

///|
fn nanos_text(nanos : Int32) -> String {
  let mut raw = nanos.to_string()
  while raw.length() < 9 {
    raw = "0" + raw
  }
  while raw.has_suffix("0") {
    raw = raw.strip_suffix("0").unwrap().to_owned()
  }
  raw
}

///|
fn signed_years(d : @types.DurationYM) -> Int32 {
  if d.negative {
    -d.years
  } else {
    d.years
  }
}

///|
fn signed_months(d : @types.DurationYM) -> Int32 {
  if d.negative {
    -d.months
  } else {
    d.months
  }
}

///|
fn duration_ds_property(
  d : @types.DurationDS,
  name : String,
) -> @types.Value raise @types.EngineError {
  let sign = if d.negative { "-" } else { "" }
  match name {
    "days" => Number(@types.decimal(sign + d.days.to_string()))
    "hours" =>
      Number(@types.decimal(sign + (d.nanos / 3600000000000L).to_string()))
    "minutes" =>
      Number(
        @types.decimal(
          sign + (d.nanos % 3600000000000L / 60000000000L).to_string(),
        ),
      )
    "seconds" => {
      let rem = d.nanos % 60000000000L
      let seconds = rem / 1000000000L
      let nanos = rem % 1000000000L
      if nanos == 0L {
        Number(@types.decimal(sign + seconds.to_string()))
      } else {
        Number(
          @types.decimal(
            sign + seconds.to_string() + "." + nanos_text(nanos.to_int()),
          ),
        )
      }
    }
    _ => Null
  }
}

///|
fn filter_value(
  target : @types.Value,
  filter : @parser.Expr,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  let items = match target {
    List(xs) => xs
    Null => return Null
    _ => [target]
  }
  if items.is_empty() {
    return List([])
  }
  let probe = evaluate_inner(filter, filter_scope(ctx, items[0])) catch {
    @types.Failure("E_NAME", _, _, _) => Null
    e => raise e
  }
  match probe {
    Number(n) => {
      if !n.is_integer() {
        raise err("E_TYPE", "filter index must be an integer")
      }
      let at = n.to_int() catch {
        _ => raise err("E_TYPE", "filter index out of range")
      }
      let at = if at < 0 { items.length() + at + 1 } else { at }
      if at < 1 || at > items.length() {
        Null
      } else {
        items[at - 1]
      }
    }
    _ => {
      let out = []
      for i, item in items {
        let keep = if i == 0 {
          probe
        } else {
          evaluate_inner(filter, filter_scope(ctx, item)) catch {
            _ => Boolean(false)
          }
        }
        match keep {
          Boolean(true) => out.push(item)
          _ => ()
        }
      }
      List(out)
    }
  }
}

///|
fn same_kind(a : @types.Value, b : @types.Value) -> Bool {
  match (a, b) {
    (Null, Null)
    | (Boolean(_), Boolean(_))
    | (Number(_), Number(_))
    | (Text(_), Text(_))
    | (Date(_), Date(_))
    | (Time(_), Time(_))
    | (DateTime(_), DateTime(_))
    | (DaysSeconds(_), DaysSeconds(_))
    | (YearsMonths(_), YearsMonths(_))
    | (List(_), List(_))
    | (Context(_), Context(_))
    | (Range(_), Range(_))
    | (Function(_), Function(_)) => true
    _ => false
  }
}

///|
/// FEEL equality with three-valued logic: operands of different types are
/// indeterminate, while null equals only null.
fn equal_value(
  a : @types.Value,
  b : @types.Value,
) -> @types.Value raise @types.EngineError {
  if a is Null || b is Null {
    return Boolean(a is Null && b is Null)
  }
  if !same_kind(a, b) {
    return Null
  }
  if a is Time(x) &&
    b is Time(y) &&
    x.zone is Named(first) &&
    y.zone is Named(second) &&
    first == second {
    return Boolean(x.seconds() == y.seconds())
  }
  for value in [a, b] {
    match value {
      DateTime(dt) if dt.time.zone is Named(_) =>
        ignore(@types.datetime_zone_offset(dt))
      Time(t) if t.zone is Named(_) =>
        if @types.standard_zone_offset(t.zone) is None {
          raise err(
            "E_ZONE_DATE_REQUIRED", "named time needs a date to resolve an offset",
          )
        }
      _ => ()
    }
  }
  Boolean(a.equals(b))
}

///|
fn binary(
  op : String,
  a : @types.Value,
  b : @types.Value,
) -> @types.Value raise @types.EngineError {
  match op {
    "=" => return equal_value(a, b)
    "!=" | "<>" =>
      return match equal_value(a, b) {
        Boolean(x) => Boolean(!x)
        _ => Null
      }
    _ => ()
  }
  if a is Null || b is Null {
    return Null
  }
  match op {
    "<" => Boolean(@types.compare_values(a, b) < 0)
    ">" => Boolean(@types.compare_values(a, b) > 0)
    "<=" => Boolean(@types.compare_values(a, b) <= 0)
    ">=" => Boolean(@types.compare_values(a, b) >= 0)
    "+" => add(a, b)
    "-" => subtract(a, b)
    "*" => multiply(a, b)
    "/" => divide(a, b)
    "**" =>
      match (a, b) {
        (Number(x), Number(y)) => Number(x.pow(y))
        _ => raise err("E_TYPE", "exponentiation requires numbers")
      }
    _ => raise err("E_OPERATOR", "unknown operator: " + op)
  }
}

///|
fn whole_days(d : @types.DurationDS) -> @bigint.BigInt {
  d.total_nanos() / 86400000000000N
}

///|
/// Ceiling of the exact signed day count, without narrowing to Int64.
fn ceil_days(d : @types.DurationDS) -> @bigint.BigInt {
  let day = 86400000000000N
  let total = d.total_nanos()
  let q = total / day
  let r = total % day
  if r > 0N {
    q + 1N
  } else {
    q
  }
}

///|
fn date_midnight_nanos(date : @types.Date) -> @bigint.BigInt {
  @bigint.BigInt::from_int64(date.ordinal()) * 86400000000000N
}

///|
fn datetime_utc_nanos(
  dt : @types.DateTime,
) -> @bigint.BigInt raise @types.EngineError {
  date_midnight_nanos(dt.date) +
  @bigint.BigInt::from_int64(dt.time.seconds()) -
  @bigint.BigInt::from_int(@types.datetime_zone_offset(dt)) * 1000000000N
}

///|
fn add(
  a : @types.Value,
  b : @types.Value,
) -> @types.Value raise @types.EngineError {
  match (a, b) {
    (Number(x), Number(y)) => Number(x.add(y))
    (Date(d), DaysSeconds(x)) =>
      Date(
        @types.date_from_ordinal(
          @bigint.BigInt::from_int64(d.ordinal()) + whole_days(x),
        ),
      )
    (DaysSeconds(x), Date(d)) =>
      Date(
        @types.date_from_ordinal(
          @bigint.BigInt::from_int64(d.ordinal()) + whole_days(x),
        ),
      )
    (Date(d), YearsMonths(x)) =>
      Date(@types.date_add_months(d, x.total_months()))
    (YearsMonths(x), Date(d)) =>
      Date(@types.date_add_months(d, x.total_months()))
    (Time(t), DaysSeconds(x)) => Time(time_add(t, x))
    (DaysSeconds(x), Time(t)) => Time(time_add(t, x))
    (DateTime(dt), DaysSeconds(x)) => DateTime(datetime_add_ds(dt, x))
    (DaysSeconds(x), DateTime(dt)) => DateTime(datetime_add_ds(dt, x))
    (DateTime(dt), YearsMonths(x)) =>
      DateTime(
        @types.datetime_of(
          @types.date_add_months(dt.date, x.total_months()),
          dt.time,
        ),
      )
    (YearsMonths(x), DateTime(dt)) =>
      DateTime(
        @types.datetime_of(
          @types.date_add_months(dt.date, x.total_months()),
          dt.time,
        ),
      )
    (DaysSeconds(x), DaysSeconds(y)) => DaysSeconds(x.add(y))
    (YearsMonths(x), YearsMonths(y)) =>
      YearsMonths(ym_of_months(x.total_months() + y.total_months()))
    (Text(x), Text(y)) => Text(x + y)
    _ =>
      raise err(
        "E_TYPE",
        "cannot add " + a.type_name() + " and " + b.type_name(),
      )
  }
}

///|
fn subtract(
  a : @types.Value,
  b : @types.Value,
) -> @types.Value raise @types.EngineError {
  match (a, b) {
    (Number(x), Number(y)) => Number(x.add(y.negate()))
    (Date(x), Date(y)) =>
      DaysSeconds(
        @types.duration_ds_of_nanos(
          @bigint.BigInt::from_int64(x.ordinal() - y.ordinal()) *
          86400000000000N,
        ),
      )
    (Date(d), DaysSeconds(x)) =>
      Date(
        @types.date_from_ordinal(
          @bigint.BigInt::from_int64(d.ordinal()) - ceil_days(x),
        ),
      )
    (Date(d), YearsMonths(x)) =>
      Date(@types.date_add_months(d, -x.total_months()))
    (Date(d), DateTime(dt)) =>
      if !dt.has_offset() {
        Null
      } else {
        DaysSeconds(
          @types.duration_ds_of_nanos(
            date_midnight_nanos(d) - datetime_utc_nanos(dt),
          ),
        )
      }
    (Time(x), Time(y)) => DaysSeconds(time_difference(x, y))
    (Time(t), DaysSeconds(x)) => Time(time_add(t, x.negate()))
    (DateTime(dt), Date(d)) =>
      if !dt.has_offset() {
        Null
      } else {
        DaysSeconds(
          @types.duration_ds_of_nanos(
            datetime_utc_nanos(dt) - date_midnight_nanos(d),
          ),
        )
      }
    (DateTime(x), DateTime(y)) => DaysSeconds(datetime_difference(x, y))
    (DateTime(dt), DaysSeconds(x)) => DateTime(datetime_add_ds(dt, x.negate()))
    (DateTime(dt), YearsMonths(x)) =>
      DateTime(
        @types.datetime_of(
          @types.date_add_months(dt.date, -x.total_months()),
          dt.time,
        ),
      )
    (DaysSeconds(x), DaysSeconds(y)) => DaysSeconds(x.subtract(y))
    (YearsMonths(x), YearsMonths(y)) =>
      YearsMonths(ym_of_months(x.total_months() - y.total_months()))
    _ =>
      raise err(
        "E_TYPE",
        "cannot subtract " + b.type_name() + " from " + a.type_name(),
      )
  }
}

///|
fn multiply(
  a : @types.Value,
  b : @types.Value,
) -> @types.Value raise @types.EngineError {
  match (a, b) {
    (Number(x), Number(y)) => Number(x.multiply(y))
    (DaysSeconds(x), Number(n)) => DaysSeconds(scale_ds(x, n))
    (Number(n), DaysSeconds(x)) => DaysSeconds(scale_ds(x, n))
    (YearsMonths(x), Number(n)) => YearsMonths(scale_ym(x, n))
    (Number(n), YearsMonths(x)) => YearsMonths(scale_ym(x, n))
    _ =>
      raise err(
        "E_TYPE",
        "cannot multiply " + a.type_name() + " by " + b.type_name(),
      )
  }
}

///|
fn divide(
  a : @types.Value,
  b : @types.Value,
) -> @types.Value raise @types.EngineError {
  match (a, b) {
    (Number(x), Number(y)) =>
      if y.is_zero() {
        Null
      } else {
        Number(x.divide(y))
      }
    (DaysSeconds(x), Number(n)) => {
      if n.is_zero() {
        raise err("E_DIV_ZERO", "division by zero")
      }
      DaysSeconds(scale_ds(x, @types.decimal_int(1).divide(n)))
    }
    (YearsMonths(x), Number(n)) => {
      if n.is_zero() {
        raise err("E_DIV_ZERO", "division by zero")
      }
      YearsMonths(scale_ym(x, @types.decimal_int(1).divide(n)))
    }
    (DaysSeconds(x), DaysSeconds(y)) =>
      if y.is_zero() {
        raise err("E_DIV_ZERO", "division by zero")
      } else {
        Number(
          @types.decimal(x.total_nanos().to_string()).divide(
            @types.decimal(y.total_nanos().to_string()),
          ),
        )
      }
    (YearsMonths(x), YearsMonths(y)) =>
      if y.total_months() == 0 {
        raise err("E_DIV_ZERO", "division by zero")
      } else {
        Number(
          @types.decimal(x.total_months().to_string()).divide(
            @types.decimal(y.total_months().to_string()),
          ),
        )
      }
    _ =>
      raise err(
        "E_TYPE",
        "cannot divide " + a.type_name() + " by " + b.type_name(),
      )
  }
}

///|
fn ym_of_months(total : Int64) -> @types.DurationYM raise @types.EngineError {
  @types.duration_ym_of_months(@bigint.BigInt::from_int64(total))
}

///|
fn scale_ds(
  d : @types.DurationDS,
  factor : @types.Decimal,
) -> @types.DurationDS raise @types.EngineError {
  let total = @types.decimal(d.total_nanos().to_string())
  let scaled = total.multiply(factor).round(0)
  @types.duration_ds_of_nanos(@types.decimal_to_scaled(scaled, 0))
}

///|
fn scale_ym(
  d : @types.DurationYM,
  factor : @types.Decimal,
) -> @types.DurationYM raise @types.EngineError {
  let total = @types.decimal(d.total_months().to_string())
  let scaled = total.multiply(factor).add(@types.decimal("0.5")).floor()
  @types.duration_ym_of_months(@types.decimal_to_scaled(scaled, 0))
}

///|
fn time_add(t : @types.Time, d : @types.DurationDS) -> @types.Time {
  let day = 86400000000000N
  let total = @bigint.BigInt::from_int64(t.seconds()) + d.total_nanos()
  let mut rest = total % day
  if rest < 0N {
    rest = rest + day
  }
  let nanos = rest.to_int64()
  let seconds = nanos / 1000000000L
  {
    hour: (seconds / 3600L).to_int(),
    minute: (seconds % 3600L / 60L).to_int(),
    second: (seconds % 60L).to_int(),
    nanos: (nanos % 1000000000L).to_int(),
    zone: t.zone,
  }
}

///|
fn datetime_add_ds(
  dt : @types.DateTime,
  d : @types.DurationDS,
) -> @types.DateTime raise @types.EngineError {
  if dt.time.zone is Named(_) && dt.date.year >= 1970 && dt.date.year <= 2100 {
    return @types.datetime_from_instant(
      dt.epoch_nanos() + d.total_nanos(),
      dt.time.zone,
    )
  }
  let day = 86400000000000N
  let base = @bigint.BigInt::from_int64(dt.date.ordinal()) * day +
    @bigint.BigInt::from_int64(dt.time.seconds())
  let total = base + d.total_nanos()
  let mut days = total / day
  let mut rest = total % day
  if rest < 0N {
    days = days - 1N
    rest = rest + day
  }
  let nanos = rest.to_int64()
  let seconds = nanos / 1000000000L
  {
    date: @types.date_from_ordinal(days),
    time: {
      hour: (seconds / 3600L).to_int(),
      minute: (seconds % 3600L / 60L).to_int(),
      second: (seconds % 60L).to_int(),
      nanos: (nanos % 1000000000L).to_int(),
      zone: dt.time.zone,
    },
  }
}

///|
fn zone_offset(t : @types.Time) -> Int64 raise @types.EngineError {
  match @types.standard_zone_offset(t.zone) {
    Some(o) => o.to_int64()
    None =>
      raise err(
        "E_ZONE_AMBIGUOUS", "time with named zone has no date to resolve DST offset",
      )
  }
}

///|
fn time_difference(
  a : @types.Time,
  b : @types.Time,
) -> @types.DurationDS raise @types.EngineError {
  if a.zone is Named(x) && b.zone is Named(y) && x == y {
    return @types.duration_ds_of_nanos(
      @bigint.BigInt::from_int64(a.seconds() - b.seconds()),
    )
  }
  let nanos = a.seconds() -
    zone_offset(a) * 1000000000L -
    (b.seconds() - zone_offset(b) * 1000000000L)
  @types.duration_ds_of_nanos(@bigint.BigInt::from_int64(nanos))
}

///|
fn datetime_difference(
  a : @types.DateTime,
  b : @types.DateTime,
) -> @types.DurationDS raise @types.EngineError {
  @types.duration_ds_of_nanos(datetime_difference_nanos(a, b))
}

///|
fn datetime_difference_nanos(
  a : @types.DateTime,
  b : @types.DateTime,
) -> @bigint.BigInt raise @types.EngineError {
  match (a.has_offset(), b.has_offset()) {
    (true, true) => a.epoch_nanos() - b.epoch_nanos()
    (false, false) => {
      let days = a.date.ordinal() - b.date.ordinal()
      @bigint.BigInt::from_int64(days) * 86400000000000N +
      @bigint.BigInt::from_int64(a.time.seconds()) -
      @bigint.BigInt::from_int64(b.time.seconds())
    }
    _ => raise err("E_TYPE", "cannot subtract zoned and unzoned date-times")
  }
}

///|
/// Compile and evaluate FEEL using the current context names.
pub fn feel_eval(
  source : String,
  ctx~ : Map[String, @types.Value] = Map([]),
) -> @types.Value raise @types.EngineError {
  let names = @builtins.lexer_names()
  for k, _ in ctx {
    names.push(k)
  }
  evaluate_inner(@parser.compile(source, names~, context=ctx), ctx)
}

///|
fn filter_scope(
  ctx : Map[String, @types.Value],
  item : @types.Value,
) -> Map[String, @types.Value] {
  let scope = ctx.copy()
  scope["item"] = item
  if item is Context(fields) {
    for k, v in fields {
      scope[k] = v
    }
  }
  scope
}

///|
/// Bind a caller clock to an isolated scope; captured functions retain this clock.
/// No process-global clock is changed. Without injection now/today remain unsupported.
pub fn with_clock(
  ctx : Map[String, @types.Value],
  clock : (() -> @types.DateTime)?,
) -> Map[String, @types.Value] {
  let scope = ctx.copy()
  if clock is Some(read) {
    scope["now"] = Function({
      name: "now",
      params: [],
      callback: _ => DateTime(read()),
    })
    scope["today"] = Function({
      name: "today",
      params: [],
      callback: _ => Date(read().date),
    })
  }
  scope
}
