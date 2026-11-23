///|
fn r251_model(body : String) -> String {
  "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' xmlns:feel='https://www.omg.org/spec/DMN/20230324/FEEL/' xmlns:ext='urn:extension' name='Root' namespace='urn:root'>" +
  body +
  "</definitions>"
}

///|
fn r251_eval(body : String) -> String raise @types.EngineError {
  @model.evaluate_decision(@model.parse_model(r251_model(body)), "D", Map([]))
  .json()
  .stringify()
}

///|
test "r251 DMN artifacts can accompany an executable model" {
  assert_eq(
    r251_eval(
      "<decision id='a' name='D'><literalExpression><text>7</text></literalExpression></decision><textAnnotation id='note'><text>Generated note</text></textAnnotation><association><sourceRef href='#a'/><targetRef href='#note'/></association><group name='Notes'/><elementCollection name='Main'><drgElement href='#a'/></elementCollection><organizationUnit name='Finance'/><performanceIndicator name='Margin'/>",
    ),
    "7",
  )
  assert_eq(
    try {
      ignore(@model.parse_model(r251_model("<unknownModelElement/>")))
      "ok"
    } catch {
      e => @types.error_code(e)
    },
    "E_DMN_UNSUPPORTED",
  )
}

///|
test "r251 duplicate DRG names are rejected with or without XML IDs" {
  let body = "<decision name='D'/><decision name='D'/>"
  let code = try {
    ignore(@model.parse_model(r251_model(body)))
    "ok"
  } catch {
    e => @types.error_code(e)
  }
  assert_eq(code, "E_DUPLICATE")
  assert_eq(
    r251_eval(
      "<decision name='D'><literalExpression><text>7</text></literalExpression></decision>",
    ),
    "7",
  )
  assert_eq(
    try {
      ignore(
        @model.parse_model(
          r251_model(
            "<decision name='a' id='dup'/><decision name='b' id='dup'/>",
          ),
        ),
      )
      "ok"
    } catch {
      e => @types.error_code(e)
    },
    "E_DUPLICATE",
  )
}

///|
test "r251 required edge metadata remains non-executable at runtime and lint" {
  let doc = "<decision name='A' id='a'><literalExpression><text>2</text></literalExpression></decision><businessKnowledgeModel name='Base' id='base'><encapsulatedLogic><literalExpression><text>3</text></literalExpression></encapsulatedLogic></businessKnowledgeModel><businessKnowledgeModel name='B' id='b'><encapsulatedLogic><literalExpression><text>Base() + 4</text></literalExpression></encapsulatedLogic><knowledgeRequirement><description>BKM source</description><requiredKnowledge href='#base'/></knowledgeRequirement></businessKnowledgeModel><decision name='D'><informationRequirement><description>Uses A</description><extensionElements><ext:requiredDecision href='#absent'/></extensionElements><requiredDecision href='#a'/></informationRequirement><knowledgeRequirement><description>Uses B</description><requiredKnowledge href='#b'/></knowledgeRequirement><literalExpression><text>A + B()</text></literalExpression></decision>"
  assert_eq(r251_eval(doc), "9")
  let parsed = @model.parse_model(r251_model(doc))
  assert_eq(@model.lint(parsed).stringify(), "[]")
}

///|
test "r251 lint detects information references to the wrong DRG kind" {
  let model = @model.parse_model(
    r251_model(
      "<inputData name='Source' id='input'/><decision name='Other' id='other'><literalExpression><text>2</text></literalExpression></decision><decision name='D'><informationRequirement><requiredDecision href='#input'/></informationRequirement><informationRequirement><requiredInput href='#other'/></informationRequirement><literalExpression><text>7</text></literalExpression></decision>",
    ),
  )
  let report = @model.lint(model).stringify()
  assert_true(report.contains("#input") && report.contains("#other"))
  assert_eq(
    try {
      ignore(@model.evaluate_decision(model, "D", Map([])))
      "ok"
    } catch {
      e => @types.error_code(e)
    },
    "E_REFERENCE",
  )
  let good = @model.parse_model(
    r251_model(
      "<decision name='Other' id='other'><literalExpression><text>2</text></literalExpression></decision><decision name='D'><informationRequirement><requiredDecision href='#other'/></informationRequirement><literalExpression><text>Other</text></literalExpression></decision>",
    ),
  )
  assert_eq(@model.lint(good).stringify(), "[]")
}

///|
test "r251 known FEEL type namespace checks qualified relation columns" {
  let prefix = "<decision name='D'><relation><column name='x' typeRef='feel:number'/><row><literalExpression><text>"
  let suffix = "</text></literalExpression></row></relation></decision>"
  assert_eq(r251_eval(prefix + "\"word\"" + suffix), "null")
  assert_eq(r251_eval(prefix + "8" + suffix), "[{\"x\":8}]")
  let foreign = "<decision name='D'><relation><column name='x' typeRef='ext:number'/><row><literalExpression><text>\"opaque\"</text></literalExpression></row></relation></decision>"
  assert_eq(r251_eval(foreign), "[{\"x\":\"opaque\"}]")
}

///|
test "r251 imported model namespace URI follows declared DMN version" {
  let version = "https://www.omg.org/spec/DMN/20191111/MODEL/"
  let body = "<import name='old' namespace='urn:old' importType='" +
    version +
    "' locationURI='old.dmn'/><decision name='D'><informationRequirement><requiredDecision href='urn:old#a'/></informationRequirement><literalExpression><text>old.A + 1</text></literalExpression></decision>"
  let child = "<definitions xmlns='" +
    version +
    "' namespace='urn:old' name='Old'><decision id='a' name='A'><literalExpression><text>5</text></literalExpression></decision></definitions>"
  let model = @model.parse_model(
    r251_model(body),
    resolver=Some((path, ns) => {
      if path != "old.dmn" || ns != "urn:old" {
        raise @types.fail("E_CONTRACT", "wrong resolver coordinates")
      }
      child
    }),
  )
  assert_eq(@model.evaluate_decision(model, "D", Map([])).text(), "6")
  let bad = try {
    ignore(
      @model.parse_model(
        r251_model(body),
        resolver=Some((_, _) => {
          "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:old'/>"
        }),
      ),
    )
    "ok"
  } catch {
    e => @types.error_code(e)
  }
  assert_eq(bad, "E_IMPORT_TYPE")
}

///|
test "r251 decision table output clauses enforce their declared type for rules and defaults" {
  let p = "<decision name='D'><decisionTable><input><inputExpression><text>1</text></inputExpression></input><output name='amount' typeRef='number'><defaultOutputEntry><text>"
  let m = "</text></defaultOutputEntry></output><output name='unit' typeRef='string'><defaultOutputEntry><text>\"USD\"</text></defaultOutputEntry></output><rule><inputEntry><text>"
  let e = "</text></inputEntry><outputEntry><text>"
  let s = "</text></outputEntry><outputEntry><text>\"USD\"</text></outputEntry></rule></decisionTable></decision>"
  assert_eq(r251_eval(p + "9" + m + "1" + e + "\"word\"" + s), "null")
  assert_eq(r251_eval(p + "\"default\"" + m + "2" + e + "8" + s), "null")
  assert_eq(
    r251_eval(p + "[9]" + m + "2" + e + "8" + s),
    "{\"amount\":9,\"unit\":\"USD\"}",
  )
  assert_eq(
    r251_eval(p + "9" + m + "1" + e + "[8]" + s),
    "{\"amount\":8,\"unit\":\"USD\"}",
  )
}

///|
test "r251 injected dependency values use the same declared output coercion as evaluated values" {
  let doc = r251_model(
    "<decision id='a' name='A'><variable name='A' typeRef='number'/><literalExpression><text>[2]</text></literalExpression></decision><decision name='D'><informationRequirement><requiredDecision href='#a'/></informationRequirement><literalExpression><text>A + 1</text></literalExpression></decision>",
  )
  let model = @model.parse_model(doc)
  assert_eq(@model.evaluate_decision(model, "D", Map([])).text(), "3")
  let supplied = @types.List([@types.Number(@types.decimal_int(4))])
  assert_eq(
    @model.evaluate_decision(model, "D", Map([("A", supplied)])).text(),
    "5",
  )
  let invalid = @types.List([@types.Text("wrong")])
  let code = try {
    ignore(@model.evaluate_decision(model, "D", Map([("A", invalid)])))
    "ok"
  } catch {
    e => @types.error_code(e)
  }
  assert_eq(code, "E_TYPE")
}

///|
test "r251 duplicate boxed formals fail rather than shadowing a parameter" {
  let boxed = "<decision name='D'><invocation><functionDefinition><formalParameter name='x'/><formalParameter name='x'/><literalExpression><text>x</text></literalExpression></functionDefinition><binding><parameter name='x'/><literalExpression><text>1</text></literalExpression></binding></invocation></decision>"
  let bkm = "<businessKnowledgeModel id='b' name='B'><encapsulatedLogic><formalParameter name='x'/><formalParameter name='x'/><literalExpression><text>x</text></literalExpression></encapsulatedLogic></businessKnowledgeModel><decision name='D'><knowledgeRequirement><requiredKnowledge href='#b'/></knowledgeRequirement><literalExpression><text>B(1,2)</text></literalExpression></decision>"
  let spaces = bkm
    .replace_all(
      old="<formalParameter name='x'/><formalParameter name='x'/>",
      new="<formalParameter name='first name'/><formalParameter name='first  name'/>",
    )
    .replace_all(old="<text>x</text>", new="<text>first name</text>")
  let unicode_spaces = spaces.replace_all(old="first  name", new="first name")
  for bad in [boxed, bkm, spaces, unicode_spaces] {
    let code = try {
      ignore(r251_eval(bad))
      "ok"
    } catch {
      e => @types.error_code(e)
    }
    assert_eq(code, "E_DMN_FUNCTION")
  }
  let valid = bkm.replace_all(
    old="<formalParameter name='x'/><formalParameter name='x'/>",
    new="<formalParameter name='x'/><formalParameter name='y'/>",
  )
  assert_eq(r251_eval(valid), "1")
}
