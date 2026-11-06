///|
fn document(ns : String, body : String) -> String {
  "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='" +
  ns +
  "'>" +
  body +
  "</definitions>"
}

///|
fn include_model(ns : String, name : String, path : String) -> String {
  "<import namespace='" +
  ns +
  "' name='" +
  name +
  "' locationURI='" +
  path +
  "' importType='https://www.omg.org/spec/DMN/20230324/MODEL/'/>"
}

///|
fn decision(body : String) -> String {
  "<decision id='d' name='d'>" + body + "</decision>"
}

///|
test "separate namespaces, imported input, BKM, decision and types" {
  let a = document(
    "a",
    "<itemDefinition name='Number'><typeRef>number</typeRef></itemDefinition><inputData id='i' name='x'><variable typeRef='Number'/></inputData>" +
    decision(
      "<informationRequirement><requiredInput href='#i'/></informationRequirement><literalExpression><text>x + 1</text></literalExpression>",
    ),
  )
  let b = document(
    "b",
    decision("<literalExpression><text>10</text></literalExpression>"),
  )
  let root = document(
    "root",
    include_model("a", "A", "a.dmn") +
    include_model("b", "B", "b.dmn") +
    decision(
      "<variable typeRef='A.Number'/><informationRequirement><requiredDecision href='a#d'/></informationRequirement><informationRequirement><requiredDecision href='b#d'/></informationRequirement><literalExpression><text>A.d + B.d</text></literalExpression>",
    ),
  )
  let model = @model.parse_model(
    root,
    resolver=Some((path, _) => if path == "a.dmn" { a } else { b }),
  )
  inspect(
    @model.evaluate_decision(
      model,
      "d",
      @types.json_context("{\"A\":{\"x\":2}}"),
    )
    .json()
    .stringify(),
    content="13",
  )
  inspect(@model.lint(model).stringify(), content="[]")
}

///|
test "import errors retain source positions and stable codes" {
  let child = document("a", "")
  let resolve : ((String, String) -> String raise @types.EngineError)? = Some((
    _,
    _,
  ) => child)
  for
    (body, expected) in [
      (
        "<import namespace='a' name='A' importType='text/plain'/>", "E_IMPORT_TYPE",
      ),
      (include_model("wrong", "A", "a.dmn"), "E_IMPORT_NAMESPACE"),
      (
        include_model("a", "A", "a.dmn") + include_model("a", "A", "a.dmn"),
        "E_IMPORT_ALIAS",
      ),
    ] {
    let result = try {
      ignore(@model.parse_model(document("root", body), resolver=resolve))
      "ok"
    } catch {
      @types.Failure(code, line, column, _) => {
        assert_true(line > 0 && column > 0)
        code
      }
    }
    assert_eq(result, expected)
  }
  inspect(
    try {
      ignore(
        @model.parse_model(document("root", include_model("a", "A", "a.dmn"))),
      )
      "ok"
    } catch {
      e => @types.error_code(e)
    },
    content="E_IMPORT_NOT_FOUND",
  )
  let cyclic = document("a", include_model("a", "A", "a.dmn"))
  inspect(
    try {
      ignore(@model.parse_model(cyclic, resolver=Some((_, _) => cyclic)))
      "ok"
    } catch {
      e => @types.error_code(e)
    },
    content="E_IMPORT_CYCLE",
  )
  inspect(
    try {
      ignore(
        @model.parse_model(
          document("root", include_model("a", "A", "a.dmn")),
          resolver=Some((_, ns) => {
            document(ns, include_model(ns + "x", "A", "a.dmn"))
          }),
        ),
      )
      "ok"
    } catch {
      e => @types.error_code(e)
    },
    content="E_IMPORT_DEPTH",
  )
}

///|
test "nested callback locations and resolver errors" {
  let root = document("root", include_model("a", "A", "sub/a.dmn"))
  let paths = []
  ignore(
    @model.parse_model(
      root,
      resolver=Some((path, ns) => {
        paths.push(path)
        if ns == "a" {
          document("a", include_model("b", "B", "b.dmn"))
        } else {
          document("b", "")
        }
      }),
    ),
  )
  inspect(paths.join(","), content="sub/a.dmn,sub/b.dmn")
  inspect(
    try {
      ignore(
        @model.parse_model(
          root,
          resolver=Some((_, _) => {
            raise @types.fail("E_IMPORT_NOT_FOUND", "missing")
          }),
        ),
      )
      "ok"
    } catch {
      @types.Failure(code, line, column, _) => {
        assert_true(line > 0 && column > 0)
        code
      }
    },
    content="E_IMPORT_NOT_FOUND",
  )
}

///|
test "ambiguous unnamed imports fail rather than overwrite" {
  let root = document(
    "root",
    include_model("a", "", "a.dmn") + include_model("b", "", "b.dmn"),
  )
  inspect(
    try {
      ignore(
        @model.parse_model(
          root,
          resolver=Some((_, ns) => {
            document(
              ns,
              decision("<literalExpression><text>1</text></literalExpression>"),
            )
          }),
        ),
      )
      "ok"
    } catch {
      e => @types.error_code(e)
    },
    content="E_IMPORT_NAME",
  )
}
