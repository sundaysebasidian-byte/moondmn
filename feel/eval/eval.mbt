///|
pub fn evaluate(
  expr : @parser.Expr,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  match expr {
    Literal(v) => v
    Name(n) =>
      match ctx.get(n) {
        Some(v) => v
        None => raise @types.fail("E_NAME", "unknown name: " + n)
      }
    Unary(op, e) =>
      match evaluate(e, ctx) {
        Number(n) => Number(if op == "-" { n.negate() } else { n })
        Null => Null
        _ => Null
      }
    Binary(op, a, b) => {
      let x = evaluate(a, ctx)
      if op == "and" && x == Boolean(false) {
        return Boolean(false)
      }
      if op == "or" && x == Boolean(true) {
        return Boolean(true)
      }
      binary(op, x, evaluate(b, ctx))
    }
    Conditional(c, a, b) =>
      match evaluate(c, ctx) {
        Boolean(true) => evaluate(a, ctx)
        Boolean(false) => evaluate(b, ctx)
        _ => Null
      }
    Sequence(xs) => List(xs.map(x => evaluate(x, ctx)))
    Record(xs) => {
      let scope = ctx.copy()
      let out = Map([])
      for pair in xs {
        if out.contains(pair.0) {
          raise @types.fail("E_DUPLICATE", "duplicate context key")
        }
        let value = evaluate(pair.1, scope)
        scope[pair.0] = value
        out[pair.0] = value
      }
      Context(out)
    }
    Path(e, name) =>
      match evaluate(e, ctx) {
        Context(c) => c.get(name).unwrap_or(Null)
        List(xs) =>
          List(
            xs.map(x => {
              match x {
                Context(c) => c.get(name).unwrap_or(Null)
                _ => Null
              }
            }),
          )
        _ => Null
      }
    Call(name, args) => @builtins.call(name, args.map(a => evaluate(a, ctx)))
  }
}

///|
pub fn binary(
  op : String,
  a : @types.Value,
  b : @types.Value,
) -> @types.Value raise @types.EngineError {
  if op == "=" {
    return Boolean(a == b)
  }
  if op == "<>" || op == "!=" {
    return Boolean(a != b)
  }
  if op == "and" {
    return match (a, b) {
      (Boolean(false), _) | (_, Boolean(false)) => Boolean(false)
      (Boolean(true), Boolean(true)) => Boolean(true)
      _ => Null
    }
  }
  if op == "or" {
    return match (a, b) {
      (Boolean(true), _) | (_, Boolean(true)) => Boolean(true)
      (Boolean(false), Boolean(false)) => Boolean(false)
      _ => Null
    }
  }
  match (a, b) {
    (Number(x), Number(y)) =>
      match op {
        "+" => Number(x.add(y))
        "-" => Number(x.add(y.negate()))
        "*" => Number(x.multiply(y))
        "/" => Number(x.divide(y))
        "<" => Boolean(x.compare(y) < 0)
        ">" => Boolean(x.compare(y) > 0)
        "<=" => Boolean(x.compare(y) <= 0)
        ">=" => Boolean(x.compare(y) >= 0)
        _ => raise @types.fail("E_OPERATOR", op)
      }
    (Text(x), Text(y)) =>
      match op {
        "+" => Text(x + y)
        "<" => Boolean(x < y)
        ">" => Boolean(x > y)
        "<=" => Boolean(x <= y)
        ">=" => Boolean(x >= y)
        _ => Null
      }
    _ => Null
  }
}

///|
pub fn feel_eval(
  source : String,
  ctx~ : Map[String, @types.Value] = Map([]),
) -> @types.Value raise @types.EngineError {
  let names = @builtins.names()
  for k, _ in ctx {
    names.push(k)
  }
  evaluate(@parser.compile(source, names~), ctx)
}
