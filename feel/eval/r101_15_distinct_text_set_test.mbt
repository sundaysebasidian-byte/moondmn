///|
test "Distinct values preserve first text occurrence and exact Unicode" {
  assert_eq(
    @eval.feel_eval(
      "distinct values([\"B\",\"a\",\"B\",\"A\",\"😀\",\"😀\",\"a\"])",
    ).text(),
    "[B, a, A, 😀]",
  )
  assert_eq(
    @eval.feel_eval("distinct values([\"a\",1,\"a\",null,null,[1],[1]])").text(),
    "[a, 1, null, [1]]",
  )
  assert_eq(@eval.feel_eval("distinct values([])").text(), "[]")
}
