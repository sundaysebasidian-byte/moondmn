///|
/// Three-valued negation used by unary test evaluation.
fn not3(value : @types.Value) -> @types.Value {
  match value {
    Boolean(b) => Boolean(!b)
    _ => Null
  }
}

///|
/// Three-valued conjunction used by unary test evaluation.
fn and3(left : @types.Value, right : @types.Value) -> @types.Value {
  match (left, right) {
    (Boolean(false), _) | (_, Boolean(false)) => Boolean(false)
    (Boolean(true), Boolean(true)) => Boolean(true)
    _ => Null
  }
}

///|
/// Membership of an input in a list that may itself contain ranges and nested
/// lists, as used by `x in [[1..3], [5..7]]`.
fn membership(
  input : @types.Value,
  items : Array[@types.Value],
) -> @types.Value raise @types.EngineError {
  if input is Null {
    return Null
  }
  let mut result : @types.Value = Boolean(false)
  for item in items {
    let hit : @types.Value = match item {
      Range(r) => Boolean(r.contains(input)) catch { _ => Null }
      List(inner) =>
        if input.equals(item) {
          Boolean(true)
        } else {
          membership(input, inner)
        }
      Null => Null
      _ => Boolean(input.equals(item))
    }
    match hit {
      Boolean(true) => return Boolean(true)
      Boolean(false) => ()
      _ => result = Null
    }
  }
  result
}

///|
/// Evaluate a unary test with FEEL three-valued logic. A result of `Null`
/// means the test is indeterminate and must propagate as null.
pub fn test_match_value(
  check : @parser.Test,
  input : @types.Value,
  ctx : Map[String, @types.Value],
) -> @types.Value raise @types.EngineError {
  match check {
    AnyTest => Boolean(true)
    NotTest(inner) => not3(test_match_value(inner, input, ctx))
    AnyOfTest(items) => {
      let mut result : @types.Value = Boolean(false)
      for item in items {
        match test_match_value(item, input, ctx) {
          Boolean(true) => return Boolean(true)
          Boolean(false) => ()
          _ => result = Null
        }
      }
      result
    }
    CompareTest(op, expr) => {
      let other = evaluate(expr, ctx)
      if input is Null || other is Null {
        return Null
      }
      match op {
        "=" => Boolean(input.equals(other))
        "!=" | "<>" => Boolean(!input.equals(other))
        _ =>
          match compare_or_null(op, input, other) {
            Some(ok) => Boolean(ok)
            None => Null
          }
      }
    }
    RangeTest(start, start_included, end, end_included) => {
      let low : @types.Value = match start {
        Some(expr) =>
          match
            compare_or_null(
              if start_included {
                ">="
              } else {
                ">"
              },
              input,
              evaluate(expr, ctx),
            ) {
            Some(ok) => Boolean(ok)
            None => Null
          }
        None => Boolean(true)
      }
      let high : @types.Value = match end {
        Some(expr) =>
          match
            compare_or_null(
              if end_included {
                "<="
              } else {
                "<"
              },
              input,
              evaluate(expr, ctx),
            ) {
            Some(ok) => Boolean(ok)
            None => Null
          }
        None => Boolean(true)
      }
      and3(low, high)
    }
    ExprTest(expr) =>
      if expr is Name("?") {
        Boolean(true)
      } else {
        let value = evaluate(expr, scope_with(ctx, "?", input))
        match value {
          Boolean(b) =>
            if !uses_input(expr) {
              Boolean(input.equals(Boolean(b)))
            } else {
              Boolean(b)
            }
          List(items) =>
            if input.equals(value) {
              Boolean(true)
            } else {
              membership(input, items)
            }
          Range(r) =>
            if input is Null {
              Null
            } else {
              Boolean(r.contains(input)) catch {
                _ => Null
              }
            }
          Null => Null
          _ => if input is Null { Null } else { Boolean(input.equals(value)) }
        }
      }
  }
}

///|
/// Match a compiled unary test against an input value.
pub fn test_matches(
  check : @parser.Test,
  input : @types.Value,
  ctx : Map[String, @types.Value],
) -> Bool raise @types.EngineError {
  test_match_value(check, input, ctx) is Boolean(true)
}

///|
fn compare_or_null(op : String, a : @types.Value, b : @types.Value) -> Bool? {
  if a is Null || b is Null {
    return None
  }
  try {
    let order = @types.compare_values(a, b)
    Some(
      match op {
        "<" => order < 0
        ">" => order > 0
        "<=" => order <= 0
        ">=" => order >= 0
        "=" => order == 0
        _ => false
      },
    )
  } catch {
    _ => None
  }
}

///|
/// Priority index of a value inside an ordered comma-separated choice list.
/// Returns -1 when the value is not present or the list is not enumerable.
pub fn allowed_rank(
  source : String,
  value : @types.Value,
  ctx : Map[String, @types.Value],
) -> Int32 raise @types.EngineError {
  let names = @builtins.names()
  for key, _ in ctx {
    names.push(key)
  }
  names.push("?")
  let check = @parser.compile_test(source, names~)
  match check {
    AnyOfTest(items) => {
      for i, item in items {
        if test_matches(item, value, ctx) {
          return i
        }
      }
      -1
    }
    _ => if test_matches(check, value, ctx) { 0 } else { -1 }
  }
}

///|
/// Evaluate a decision table input entry or an `in` operand against an input.
pub fn unary_test(
  source : String,
  input : @types.Value,
  ctx : Map[String, @types.Value],
) -> Bool raise @types.EngineError {
  let names = @builtins.names()
  for key, _ in ctx {
    names.push(key)
  }
  names.push("?")
  let check = @parser.compile_test(source, names~)
  test_matches(check, input, scope_with(ctx, "?", input))
}

///|
// Predicate syntax depends on a reference to ?, including nested expressions.
fn uses_input(expr : @parser.Expr) -> Bool {
  match expr {
    Name(name) => name == "?"
    Lit(_) => false
    External(value)
    | Unary(_, value)
    | Path(value, _)
    | InstanceOf(value, _)
    | FunctionDef(_, value)
    | TypedFunctionDef(_, value) => uses_input(value)
    Binary(_, left, right) | Seq(left, right) | Filter(left, right) =>
      uses_input(left) || uses_input(right)
    IfThenElse(a, b, c) | Between(a, b, c) =>
      uses_input(a) || uses_input(b) || uses_input(c)
    ListLit(items) => items.iter().any(uses_input)
    ContextLit(items) => items.iter().any(item => uses_input(item.1))
    RangeLit(start, _, end, _) =>
      (start is Some(value) && uses_input(value)) ||
      (end is Some(value) && uses_input(value))
    Call(function, args) =>
      uses_input(function) || args.iter().any(arg => uses_input(arg.value))
    For(bindings, body) | SomeIn(bindings, body) | EveryIn(bindings, body) =>
      bindings.iter().any(binding => uses_input(binding.1)) || uses_input(body)
    In(value, check) => uses_input(value) || test_uses_input(check)
  }
}

///|
fn test_uses_input(check : @parser.Test) -> Bool {
  match check {
    AnyTest => false
    NotTest(inner) => test_uses_input(inner)
    CompareTest(_, expr) | ExprTest(expr) => uses_input(expr)
    AnyOfTest(items) => items.iter().any(test_uses_input)
    RangeTest(start, _, end, _) =>
      (start is Some(value) && uses_input(value)) ||
      (end is Some(value) && uses_input(value))
  }
}
