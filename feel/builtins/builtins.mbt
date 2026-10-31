///|
pub fn names() -> Array[String] {
  [
    "not", "string", "number", "count", "sum", "min", "max", "mean", "all", "any",
    "contains", "starts with", "ends with", "string length", "upper case", "lower case",
    "list contains", "append", "concatenate", "reverse", "distinct values", "flatten",
    "abs", "get value", "get entries",
  ]
}

///|
fn aggregate(
  xs : Array[@types.Value],
  op : String,
) -> @types.Value raise @types.EngineError {
  if xs.is_empty() {
    return Null
  }
  let mut total = @types.decimal("0")
  let mut selected = xs[0]
  for x in xs {
    match x {
      Number(n) => {
        total = total.add(n)
        if selected is Number(s) {
          if (op == "min" && n.compare(s) < 0) ||
            (op == "max" && n.compare(s) > 0) {
            selected = x
          }
        }
      }
      _ => return Null
    }
  }
  match op {
    "min" | "max" => selected
    "mean" => Number(total.divide(@types.decimal(xs.length().to_string())))
    _ => Number(total)
  }
}

///|
fn flatten(
  v : @types.Value,
  out : Array[@types.Value],
  depth : Int32,
) -> Unit raise @types.EngineError {
  if depth > 128 {
    raise @types.fail("E_LIMIT", "flatten nesting")
  }
  match v {
    List(xs) =>
      for x in xs {
        flatten(x, out, depth + 1)
      }
    _ => out.push(v)
  }
}

///|
pub fn call(
  name : String,
  xs : Array[@types.Value],
) -> @types.Value raise @types.EngineError {
  match (name, xs) {
    ("not", [Boolean(b)]) => Boolean(!b)
    ("not", [_]) => Null
    ("number", [Text(s)]) => Number(@types.decimal(s))
    ("string", [Text(s)]) => Text(s)
    ("string", [Number(n)]) => Text(n.text())
    ("string", [Boolean(b)]) => Text(b.to_string())
    ("count", [List(vs)]) => Number(@types.decimal(vs.length().to_string()))
    ("sum" | "min" | "max" | "mean", [List(vs)]) => aggregate(vs, name)
    ("sum" | "min" | "max" | "mean", _) => aggregate(xs, name)
    ("string length", [Text(s)]) =>
      Number(@types.decimal(s.to_array().length().to_string()))
    ("upper case", [Text(s)]) => Text(s.to_upper())
    ("lower case", [Text(s)]) => Text(s.to_lower())
    ("contains", [Text(s), Text(t)]) => Boolean(s.contains(t))
    ("starts with", [Text(s), Text(t)]) => Boolean(s.has_prefix(t))
    ("ends with", [Text(s), Text(t)]) => Boolean(s.has_suffix(t))
    ("list contains", [List(vs), v]) => Boolean(vs.contains(v))
    ("reverse", [List(vs)]) => List(vs.rev())
    ("distinct values", [List(vs)]) => {
      let out = []
      for v in vs {
        if !out.contains(v) {
          out.push(v)
        }
      }
      List(out)
    }
    ("flatten", [v]) => {
      let out = []
      flatten(v, out, 0)
      List(out)
    }
    ("concatenate", _) => {
      let out = []
      for v in xs {
        match v {
          List(vs) => out.append(vs)
          _ => return Null
        }
      }
      List(out)
    }
    ("append", [List(vs), .. rest]) => {
      let out = vs.copy()
      for v in rest {
        out.push(v)
      }
      List(out)
    }
    ("all" | "any", [List(vs)]) => {
      let mut unknown = false
      for v in vs {
        if name == "all" && v == Boolean(false) {
          return Boolean(false)
        }
        if name == "any" && v == Boolean(true) {
          return Boolean(true)
        }
        if !(v is Boolean(_)) {
          unknown = true
        }
      }
      if unknown {
        Null
      } else {
        Boolean(name == "all")
      }
    }
    ("abs", [Number(n)]) =>
      Number(if n.compare(@types.decimal("0")) < 0 { n.negate() } else { n })
    ("get value", [Context(c), Text(k)]) => c.get(k).unwrap_or(Null)
    ("get entries", [Context(c)]) => {
      let keys = c.keys().to_array()
      keys.sort()
      List(
        keys.map(k => @types.Context(Map([("key", Text(k)), ("value", c[k])]))),
      )
    }
    _ =>
      raise @types.fail(
        "E_BUILTIN_UNSUPPORTED",
        "unsupported function or arguments: " + name,
      )
  }
}
