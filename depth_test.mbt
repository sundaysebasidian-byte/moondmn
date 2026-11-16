///|
test "operator and postfix chains fail structurally before recursive consumers" {
  for
    source in [
      Array::make(5000, "1").join("+"),
      Array::make(5000, "-").join("") + "1",
      "x" + Array::make(5000, ".a").join(""),
      "[1]" + Array::make(5000, "[1]").join(""),
      "abs" + Array::make(5000, "(1)").join(""),
      "1" + Array::make(5000, " instance of number").join(""),
      Array::make(5000, "not(").join("") +
      "true" +
      Array::make(5000, ")").join(""),
      "1 instance of " +
      Array::make(5000, "list<").join("") +
      "number" +
      Array::make(5000, ">").join(""),
    ] {
    let code = try {
      ignore(@moondmn.compile(source))
      "OK"
    } catch {
      e => @types.error_code(e)
    }
    assert_eq(code, "E_LIMIT")
  }
  assert_eq(@moondmn.feel_eval(Array::make(128, "1").join("+")), "128")
}

///|
test "caller-built trees are validated before evaluation" {
  let mut tree = @parser.Expr::Lit(@types.Number(@types.decimal_int(1)))
  for _ in 0..<5000 {
    tree = @parser.Unary("-", tree)
  }
  let code = try {
    ignore(@moondmn.evaluate_compiled(tree, "{}"))
    "OK"
  } catch {
    e => @types.error_code(e)
  }
  assert_eq(code, "E_LIMIT")
}

///|
test "model_uri support and XML nesting are explicit" {
  for
    model_uri in [
      "http://www.omg.org/spec/DMN/20151101/dmn.xsd", "https://www.omg.org/spec/DMN/20180521/MODEL/",
    ] {
    let code = try {
      ignore(@moondmn.parse_model("<definitions xmlns='" + model_uri + "'/>"))
      "OK"
    } catch {
      e => @types.error_code(e)
    }
    assert_eq(code, "E_DMN_NAMESPACE")
  }
  for model_uri in ["20191111", "20211108", "20230324"] {
    ignore(
      @moondmn.parse_model(
        "<definitions xmlns='https://www.omg.org/spec/DMN/" +
        model_uri +
        "/MODEL/'/>",
      ),
    )
  }
  let code = try {
    ignore(
      @moondmn.parse_model(
        Array::make(1000, "<x>").join("") + Array::make(1000, "</x>").join(""),
      ),
    )
    "OK"
  } catch {
    e => @types.error_code(e)
  }
  assert_eq(code, "E_LIMIT")
  // Both the FEEL text printer and JSON encoder see bounded nested values.
  ignore(
    @moondmn.feel_eval(
      Array::make(100, "[").join("") + "1" + Array::make(100, "]").join(""),
    ),
  )
}
