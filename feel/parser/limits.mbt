///|
fn validate_expr_at(e : Expr, depth : Int32) -> Unit raise @types.EngineError {
  if depth > 128 {
    raise @types.fail("E_LIMIT", "AST nesting exceeds 128")
  }
  fn expr(e : Expr) -> Unit raise @types.EngineError {
    validate_expr_at(e, depth + 1)
  }
  fn check(t : Test) -> Unit raise @types.EngineError {
    validate_test_at(t, depth + 1)
  }
  match e {
    Lit(_) | Name(_) => ()
    Unary(_, a)
    | Path(a, _)
    | External(a)
    | FunctionDef(_, a)
    | TypedFunctionDef(_, a)
    | InstanceOf(a, _) => expr(a)
    Binary(_, a, b) | Seq(a, b) | Filter(a, b) => {
      expr(a)
      expr(b)
    }
    IfThenElse(a, b, c) | Between(a, b, c) => {
      expr(a)
      expr(b)
      expr(c)
    }
    ListLit(xs) =>
      for x in xs {
        expr(x)
      }
    ContextLit(xs) =>
      for x in xs {
        expr(x.1)
      }
    RangeLit(a, _, b, _) => {
      if a is Some(x) {
        expr(x)
      }
      if b is Some(x) {
        expr(x)
      }
    }
    Call(a, xs) => {
      expr(a)
      for x in xs {
        expr(x.value)
      }
    }
    For(xs, a) | SomeIn(xs, a) | EveryIn(xs, a) => {
      expr(a)
      for x in xs {
        expr(x.1)
      }
    }
    In(a, t) => {
      expr(a)
      check(t)
    }
  }
}

///|
fn validate_test_at(t : Test, depth : Int32) -> Unit raise @types.EngineError {
  if depth > 128 {
    raise @types.fail("E_LIMIT", "AST nesting exceeds 128")
  }
  fn expr(e : Expr) -> Unit raise @types.EngineError {
    validate_expr_at(e, depth + 1)
  }
  fn check(t : Test) -> Unit raise @types.EngineError {
    validate_test_at(t, depth + 1)
  }
  match t {
    AnyTest => ()
    NotTest(t) => check(t)
    CompareTest(_, a) | ExprTest(a) => expr(a)
    RangeTest(a, _, b, _) => {
      if a is Some(x) {
        expr(x)
      }
      if b is Some(x) {
        expr(x)
      }
    }
    AnyOfTest(xs) =>
      for x in xs {
        check(x)
      }
  }
}

///|
/// Bound trees before recursive consumers, including caller-built ASTs.
pub fn validate(expr : Expr) -> Unit raise @types.EngineError {
  validate_expr_at(expr, 1)
}

///|
pub fn validate_test(check : Test) -> Unit raise @types.EngineError {
  validate_test_at(check, 1)
}
