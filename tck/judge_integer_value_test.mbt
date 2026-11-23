///|
test "Typed TCK integer values respect XML integer lexical space and bounds" {
  for
    (kind, source, expected) in [
      ("int", "3.5", "E_TCK_VALUE"),
      ("integer", "1e2", "E_TCK_VALUE"),
      ("byte", "128", "E_TCK_VALUE"),
      ("byte", "-128", "-128"),
      ("long", "-9223372036854775809", "E_TCK_VALUE"),
      ("long", "9223372036854775807", "9223372036854775807"),
      ("nonNegativeInteger", "-1", "E_TCK_VALUE"),
      ("integer", "+0001", "1"),
      ("decimal", "3.5", "3.5"),
    ] {
    let xml = "<input xmlns:i='http://www.w3.org/2001/XMLSchema-instance'><value i:type='xs:" +
      kind +
      "'>" +
      source +
      "</value></input>"
    let result = @tck.value(@xml.parse(xml)).text() catch {
      e => @types.error_code(e)
    }
    assert_eq(result, expected)
  }
}
