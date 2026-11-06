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
test "unnamed imports retain the first name and expose disjoint names" {
  let a = document(
    "a",
    decision("<literalExpression><text>4</text></literalExpression>") +
    "<decision id='a' name='OnlyA'><literalExpression><text>10</text></literalExpression></decision>",
  )
  let b = document(
    "b",
    decision("<literalExpression><text>5</text></literalExpression>") +
    "<decision id='b' name='OnlyB'><literalExpression><text>20</text></literalExpression></decision>",
  )
  for
    (expression, expected, first) in [
      ("d + OnlyA + OnlyB", "34", "a"),
      ("d + OnlyA + OnlyB", "34", "b"),
      ("OnlyA + OnlyB", "30", "a"),
    ] {
    let root = document(
      "root",
      include_model("a", "", "a.dmn") +
      include_model("b", "", "b.dmn") +
      "<decision id='out' name='Out'><informationRequirement><requiredDecision href='" +
      first +
      "#d'/></informationRequirement><informationRequirement><requiredDecision href='" +
      (if first == "a" { "b" } else { "a" }) +
      "#d'/></informationRequirement><informationRequirement><requiredDecision href='a#a'/></informationRequirement><informationRequirement><requiredDecision href='b#b'/></informationRequirement><literalExpression><text>" +
      expression +
      "</text></literalExpression></decision>",
    )
    let model = @model.parse_model(
      root,
      resolver=Some((_, ns) => if ns == "a" { a } else { b }),
    )
    inspect(
      @model.evaluate_decision(model, "Out", Map([])).json().stringify(),
      content=expected,
    )
  }
}

///|
test "local names survive unnamed imports regardless of requirement order" {
  let child = document(
    "child", "<decision id='keep' name='Keep'><literalExpression><text>99</text></literalExpression></decision><decision id='extra' name='Extra'><literalExpression><text>7</text></literalExpression></decision>",
  )
  let root = document(
    "root",
    "<decision id='keep' name='Keep'><literalExpression><text>1</text></literalExpression></decision>" +
    include_model("child", "", "child.dmn") +
    "<decision id='out' name='Out'><informationRequirement><requiredDecision href='#keep'/></informationRequirement><informationRequirement><requiredDecision href='child#keep'/></informationRequirement><informationRequirement><requiredDecision href='child#extra'/></informationRequirement><literalExpression><text>Keep + Extra</text></literalExpression></decision>",
  )
  let model = @model.parse_model(root, resolver=Some((_, _) => child))
  inspect(
    @model.evaluate_decision(model, "Out", Map([])).json().stringify(),
    content="8",
  )
}

///|
test "cycle diagnostics identify the closing import" {
  let a = document("a", "\n" + include_model("b", "B", "b.dmn"))
  let b = document("b", "\n\n" + include_model("a", "A", "a.dmn"))
  inspect(
    try {
      ignore(
        @model.parse_model(
          a,
          resolver=Some((_, ns) => if ns == "a" { a } else { b }),
        ),
      )
      "ok"
    } catch {
      @types.Failure(code, line, column, message) =>
        code + " " + line.to_string() + ":" + column.to_string() + " " + message
    },
    content="E_IMPORT_CYCLE 3:1 import cycle in b.dmn:3:1: a",
  )
}

///|
test "disjoint unnamed imports expose both models" {
  let root = document(
    "root",
    include_model("a", "", "a.dmn") +
    include_model("b", "", "b.dmn") +
    decision(
      "<informationRequirement><requiredDecision href='a#a'/></informationRequirement><informationRequirement><requiredDecision href='b#b'/></informationRequirement><literalExpression><text>OnlyA + OnlyB</text></literalExpression>",
    ),
  )
  let model = @model.parse_model(
    root,
    resolver=Some((_, ns) => {
      document(
        ns,
        if ns == "a" {
          "<decision id='a' name='OnlyA'><literalExpression><text>10</text></literalExpression></decision>"
        } else {
          "<decision id='b' name='OnlyB'><literalExpression><text>20</text></literalExpression></decision>"
        },
      )
    }),
  )
  inspect(
    @model.evaluate_decision(model, "d", Map([])).json().stringify(),
    content="30",
  )
}

///|
test "unnamed input and type collisions retain local or first declarations" {
  let declarations = "<itemDefinition name='T'><typeRef>number</typeRef></itemDefinition><inputData id='x' name='x'><variable typeRef='T'/></inputData>"
  let other = "<itemDefinition name='T'><typeRef>string</typeRef></itemDefinition><inputData id='x' name='x'><variable typeRef='T'/></inputData>"
  for has_local in [true, false] {
    let root = document(
      "root",
      (if has_local { declarations } else { include_model("a", "", "a.dmn") }) +
      include_model("b", "", "b.dmn") +
      decision(
        "<variable typeRef='T'/><informationRequirement><requiredInput href='b#x'/></informationRequirement>" +
        (if has_local {
          "<informationRequirement><requiredInput href='#x'/></informationRequirement>"
        } else {
          "<informationRequirement><requiredInput href='a#x'/></informationRequirement>"
        }) +
        "<literalExpression><text>if x instance of T then x + 1 else 99</text></literalExpression>",
      ),
    )
    let model = @model.parse_model(
      root,
      resolver=Some((_, ns) => {
        document(ns, if ns == "a" { declarations } else { other })
      }),
    )
    let inputs = @types.json_context("{\"x\":4}")
    @model.bind_input(inputs, "x", @types.Text("wrong"), model_namespace="b")
    inspect(
      @model.evaluate_decision(model, "d", inputs).json().stringify(),
      content="5",
    )
  }
}

///|
test "named aliases remain distinct from local and unnamed elements" {
  let child = document(
    "a",
    decision("<literalExpression><text>4</text></literalExpression>"),
  )
  inspect(
    try {
      ignore(
        @model.parse_model(
          document(
            "root",
            include_model("a", "Amount", "a.dmn") +
            "<decision name='Amount'><literalExpression><text>1</text></literalExpression></decision>",
          ),
          resolver=Some((_, _) => child),
        ),
      )
      "ok"
    } catch {
      e => @types.error_code(e)
    },
    content="E_IMPORT_ALIAS",
  )
  let root = document(
    "root",
    include_model("a", "A", "a.dmn") +
    include_model("b", "", "b.dmn") +
    decision(
      "<informationRequirement><requiredDecision href='a#d'/></informationRequirement><informationRequirement><requiredDecision href='b#A'/></informationRequirement><literalExpression><text>A.d</text></literalExpression>",
    ),
  )
  let model = @model.parse_model(
    root,
    resolver=Some((_, ns) => {
      if ns == "a" {
        child
      } else {
        document(
          "b", "<decision id='A' name='A'><literalExpression><text>99</text></literalExpression></decision>",
        )
      }
    }),
  )
  inspect(
    @model.evaluate_decision(model, "d", Map([])).json().stringify(),
    content="4",
  )
}

///|
test "nested unnamed imports do not hide direct decisions" {
  let c = document(
    "c", "<decision id='e' name='Extra'><literalExpression><text>7</text></literalExpression></decision>",
  )
  let a = document(
    "a",
    include_model("c", "", "c.dmn") +
    "<decision id='only' name='OnlyA'><literalExpression><text>10</text></literalExpression></decision>",
  )
  let b = document(
    "b", "<decision id='e' name='Extra'><literalExpression><text>3</text></literalExpression></decision><decision id='o' name='Other'><literalExpression><text>1</text></literalExpression></decision>",
  )
  for a_first in [true, false] {
    let imports = if a_first {
      include_model("a", "", "a.dmn") + include_model("b", "", "b.dmn")
    } else {
      include_model("b", "", "b.dmn") + include_model("a", "", "a.dmn")
    }
    let root = document(
      "root",
      imports +
      decision(
        "<informationRequirement><requiredDecision href='b#e'/></informationRequirement><informationRequirement><requiredDecision href='b#o'/></informationRequirement><informationRequirement><requiredDecision href='a#only'/></informationRequirement><literalExpression><text>Extra + Other + OnlyA</text></literalExpression>",
      ),
    )
    let model = @model.parse_model(
      root,
      resolver=Some((_, ns) => {
        if ns == "a" {
          a
        } else if ns == "b" {
          b
        } else {
          c
        }
      }),
    )
    inspect(
      @model.evaluate_decision(model, "d", Map([])).json().stringify(),
      content="14",
    )
  }
}

///|
test "nested unnamed types agree with direct typeRef and instance of" {
  let c = document(
    "c", "<itemDefinition name='T'><typeRef>string</typeRef></itemDefinition>",
  )
  let a = document("a", include_model("c", "", "c.dmn"))
  let b = document(
    "b", "<itemDefinition name='T'><typeRef>number</typeRef></itemDefinition>",
  )
  for a_first in [true, false] {
    let imports = if a_first {
      include_model("a", "", "a.dmn") + include_model("b", "", "b.dmn")
    } else {
      include_model("b", "", "b.dmn") + include_model("a", "", "a.dmn")
    }
    for
      (expression, input, typed, expected) in [
        ("if x instance of T then 1 else 0", "4", true, "1"),
        ("if x instance of T then 1 else 0", "\"hi\"", false, "0"),
        ("x", "4", true, "4"),
      ] {
      let root = document(
        "root",
        imports +
        "<inputData id='x' name='x'>" +
        (if typed { "<variable typeRef='T'/>" } else { "" }) +
        "</inputData>" +
        decision(
          (if typed { "<variable typeRef='T'/>" } else { "" }) +
          "<informationRequirement><requiredInput href='#x'/></informationRequirement><literalExpression><text>" +
          expression +
          "</text></literalExpression>",
        ),
      )
      let model = @model.parse_model(
        root,
        resolver=Some((_, ns) => {
          if ns == "a" {
            a
          } else if ns == "b" {
            b
          } else {
            c
          }
        }),
      )
      inspect(
        @model.evaluate_decision(
          model,
          "d",
          @types.json_context("{\"x\":" + input + "}"),
        )
        .json()
        .stringify(),
        content=expected,
      )
    }
  }
}
