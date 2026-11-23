///|
fn r251_fixture(body : String) -> @xml.Node raise @types.EngineError {
  @xml.parse(
    "<expected xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:xs='http://www.w3.org/2001/XMLSchema'>" +
    body +
    "</expected>",
  )
}

///|
fn r251_value(body : String) -> String {
  @tck.value(r251_fixture(body)).json().stringify() catch {
    e => @types.error_code(e)
  }
}

///|
test "r251 decimal fixtures reject exponents without changing float fixtures" {
  assert_eq(
    r251_value("<value xsi:type='xs:decimal'>1e2</value>"),
    "E_TCK_VALUE",
  )
  assert_eq(r251_value("<value xsi:type='xs:double'>1e2</value>"), "100")
  assert_eq(r251_value("<value xsi:type='xs:decimal'>+.5</value>"), "0.5")
  assert_eq(
    r251_value("<value xsi:type='xs:decimal'>1.2.3</value>"),
    "E_TCK_VALUE",
  )
}

///|
test "r251 conflicting TCK value shapes and duplicate fields are rejected" {
  assert_eq(r251_value("<value>x</value><list/>"), "E_TCK_VALUE")
  assert_eq(r251_value("<value>x</value><value>y</value>"), "E_TCK_VALUE")
  assert_eq(
    r251_value(
      "<component name='a'><value>x</value></component><component name='a'><value>y</value></component>",
    ),
    "E_TCK_VALUE",
  )
  assert_eq(
    r251_value(
      "<component name='a'><value>x</value></component><component name='b'><value>y</value></component>",
    ),
    "{\"a\":\"x\",\"b\":\"y\"}",
  )
  assert_eq(r251_value("<list/>"), "[]")
}

///|
test "r251 xsi nil is valid for list and component rather than just scalar values" {
  assert_eq(r251_value("<list xsi:nil='true'/>"), "null")
  assert_eq(r251_value("<component name='a' xsi:nil='1'/>"), "{\"a\":null}")
  assert_eq(r251_value("<value xsi:nil='false'/>"), "\"\"")
  assert_eq(r251_value("<value xsi:nil='broken'/>"), "E_TCK_VALUE")
  assert_eq(
    r251_value("<list xsi:nil='true'><item><value>v</value></item></list>"),
    "E_TCK_VALUE",
  )
}
