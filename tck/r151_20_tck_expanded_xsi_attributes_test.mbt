///|
test "TCK nil and type attributes match the XML Schema-instance namespace" {
  assert_eq(
    @tck.value(
      @xml.parse(
        "<input xmlns:i='http://www.w3.org/2001/XMLSchema-instance' xmlns:ext='urn:other'><value ext:nil='true'>visible</value></input>",
      ),
    ).type_name(),
    "string",
  )
  assert_eq(
    @tck.value(
      @xml.parse(
        "<input xmlns:i='http://www.w3.org/2001/XMLSchema-instance' xmlns:ext='urn:other'><value i:nil='1'>placeholder</value></input>",
      ),
    ).type_name(),
    "null",
  )
  assert_eq(
    @tck.value(
      @xml.parse(
        "<input xmlns:i='http://www.w3.org/2001/XMLSchema-instance' xmlns:ext='urn:other'><value i:nil='true'>placeholder</value></input>",
      ),
    ).type_name(),
    "null",
  )
  assert_eq(
    @tck.value(
      @xml.parse(
        "<input xmlns:i='http://www.w3.org/2001/XMLSchema-instance' xmlns:ext='urn:other'><value ext:type='xsd:integer'>7</value></input>",
      ),
    ).type_name(),
    "string",
  )
  assert_eq(
    @tck.value(
      @xml.parse(
        "<input xmlns:i='http://www.w3.org/2001/XMLSchema-instance' xmlns:ext='urn:other'><value i:type='xsd:integer'>7</value></input>",
      ),
    ).type_name(),
    "number",
  )
  assert_eq(
    @tck.value(
      @xml.parse(
        "<input xmlns:i='http://www.w3.org/2001/XMLSchema-instance' xmlns:ext='urn:other'><value i:nil='0'>visible</value></input>",
      ),
    ).text(),
    "visible",
  )
}
