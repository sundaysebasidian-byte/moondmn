///|
test "TCK type QNames resolve the in-scope XML Schema prefix" {
  let schema_alias = "<input xmlns:i='http://www.w3.org/2001/XMLSchema-instance' xmlns:schema='http://www.w3.org/2001/XMLSchema'><value i:type='schema:decimal'>1.25</value></input>"
  assert_eq(@tck.value(@xml.parse(schema_alias)).type_name(), "number")
  assert_eq(@tck.value(@xml.parse(schema_alias)).text(), "1.25")
  let implicit_xml = "<input xmlns:i='http://www.w3.org/2001/XMLSchema-instance'><value i:type='xml:decimal'>1.25</value></input>"
  let rejected_xml = try {
    ignore(@tck.value(@xml.parse(implicit_xml)))
    false
  } catch {
    @types.Failure("E_TCK_TYPE_UNSUPPORTED", _, _, _) => true
    e => raise e
  }
  assert_true(rejected_xml)
  let redeclared = "<input xmlns:i='http://www.w3.org/2001/XMLSchema-instance' xmlns:xs='http://www.w3.org/2001/XMLSchema'><value xmlns:xs='urn:other' i:type='xs:decimal'>1.25</value></input>"
  let rejected = try {
    ignore(@tck.value(@xml.parse(redeclared)))
    false
  } catch {
    @types.Failure("E_TCK_TYPE_UNSUPPORTED", _, _, _) => true
    e => raise e
  }
  assert_true(rejected)
  assert_eq(
    @tck.value(
      @xml.parse(
        "<input xmlns:i='http://www.w3.org/2001/XMLSchema-instance' xmlns:ext='urn:other'><value i:type='xsd:integer'>7</value></input>",
      ),
    ).type_name(),
    "number",
  )
}
