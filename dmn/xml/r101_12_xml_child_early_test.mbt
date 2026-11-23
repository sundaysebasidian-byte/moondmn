///|
test "XML child lookup preserves first same-namespace match" {
  let root = @xml.parse(
    "<root xmlns='urn:our' xmlns:x='urn:other'><x:item>wrong</x:item><item>first</item><item>second</item></root>",
  )
  assert_eq(root.child("item").unwrap().text, "first")
  assert_eq(root.all("item").length(), 2)
  assert_true(root.child("missing") is None)
  assert_eq(root.child("item").unwrap().uri, "urn:our")
}
