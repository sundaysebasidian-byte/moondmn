///|
test "TCK errorResult XML boolean lexical forms are equivalent" {
  let model = @model.parse_model("<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision name='d' id='d'><literalExpression><text>null</text></literalExpression></decision></definitions>")
  for (flag, expected) in [("1","ok"),(" true ","ok"),("0","E_TCK_RESULT"),("false","E_TCK_RESULT")] {
    let node = @xml.parse("<testCase><resultNode name='d' errorResult='" + flag + "'/></testCase>")
    let result = try { check_case(model,node,None); "ok" } catch { e => @types.error_code(e) }
    assert_eq(result,expected)
  }
}
