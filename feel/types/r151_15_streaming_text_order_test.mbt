///|
test "Text comparison keeps Unicode scalar order and exact prefix lengths" {
  fn cmp(a : String, b : String) -> Int32 raise @types.EngineError {
    @types.compare_values(@types.Text(a), @types.Text(b))
  }
  assert_eq(cmp("😀", "\uE000"), 1)
  assert_eq(cmp("a", "a😀🚀z"), -3)
  assert_eq(cmp("a😀🚀z", "a"), 3)
  assert_eq(cmp("😀", "😀"), 0)
  assert_eq(cmp("a", "z"), -1)
  assert_eq(cmp("e\u0301", "é"), -1)

  let astral = "😀αe\u0301".repeat(16)
  let same = astral + "終"
  assert_eq(cmp(same, same), 0)
  assert_eq(cmp("a" + astral, "z" + astral), -1)
  assert_eq(cmp("z" + astral, "a" + astral), 1)
  assert_eq(cmp(astral + "😀", astral + "\uE000"), 1)
  assert_eq(cmp(astral + "\uE000", astral + "😀"), -1)
  assert_eq(cmp(astral + "😀e\u0301", astral), 3)
  assert_eq(cmp(astral, astral + "😀e\u0301"), -3)
  assert_eq(cmp("x", "x" + "😀".repeat(20)), -20)
  assert_eq(cmp("x" + "😀".repeat(20), "x"), 20)
}
