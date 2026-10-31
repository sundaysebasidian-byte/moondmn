///|
test "R1 I4 named arguments bind null and reject ambiguous binding" {
  inspect(
    @moondmn.feel_eval("{f: function(a,b) [a,b], r:f(a:1)}.r"),
    content="[1,null]",
  )
  inspect(
    @moondmn.feel_eval("{f: function(a,b) [a,b], r:f(b:2)}.r"),
    content="[null,2]",
  )
  for
    source in [
      "(function(a,b) a)(1)", "(function(a,b) a)(a:1,a:2)", "(function(a,b) a)(c:1)",
      "(function(a,b) a)(1,b:2)",
    ] {
    let code = try {
      ignore(@moondmn.feel_eval(source))
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_ARITY")
  }
}

///|
test "R1 I4 missing named BKM parameter is null" {
  let model = @moondmn.parse_model(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><businessKnowledgeModel id='f' name='f'><encapsulatedLogic><formalParameter name='a'/><formalParameter name='b'/><literalExpression><text>[a,b]</text></literalExpression></encapsulatedLogic></businessKnowledgeModel><decision id='d' name='d'><knowledgeRequirement><requiredKnowledge href='#f'/></knowledgeRequirement><literalExpression><text>f(a:1)</text></literalExpression></decision></definitions>",
  )
  inspect(@moondmn.evaluate_decision(model, "d", "{}"), content="[1,null]")
}

///|
test "R1 I4 builtin named parameters bind null including interior gaps" {
  inspect(@moondmn.feel_eval("is(value1:1)"), content="false")
  inspect(@moondmn.feel_eval("is(value2:1)"), content="false")
  inspect(
    @moondmn.feel_eval("substring(string: \"abc\", start position: 2)"),
    content="\"bc\"",
  )
  inspect(
    @moondmn.feel_eval("string join(list: [\"a\",\"b\"])"),
    content="\"ab\"",
  )
  inspect(@moondmn.feel_eval("number(from: \"123\")"), content="123")
}

///|
test "R1 I4 optional overload selection preserves explicit null" {
  inspect(@moondmn.feel_eval("floor(n:1.56)"), content="1")
  inspect(@moondmn.feel_eval("floor(n:1.56,scale:null)"), content="null")
  inspect(@moondmn.feel_eval("ceiling(1.56,null)"), content="null")
}
