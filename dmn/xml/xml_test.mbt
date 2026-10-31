///|
test "namespace CDATA and entities" {
  let n = @xml.parse(
    "<d:r xmlns:d='urn:dmn'><d:text>&lt;<![CDATA[ 3]]></d:text><text xmlns='urn:other'>bad</text></d:r>",
  )
  inspect(n.content("text"), content="< 3")
  assert_eq(n.all("text").length(), 1)
  assert_true(
    try {
      ignore(@xml.parse("<!DOCTYPE r><r/>"))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@xml.parse("<a>\n</b>"))
      false
    } catch {
      _ => true
    },
  )
}
