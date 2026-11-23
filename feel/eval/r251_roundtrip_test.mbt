///|
test "r251 stringify comparison ranges with escaped string and temporal endpoints" {
  for
    source in [
      "(!=\"A\\\"B\")", "(=@\"2020-01-01\")", "(!=time(\"12:02:00@Asia/Tokyo\"))",
    ] {
    let original = @eval.feel_eval(source)
    assert_true(original is Range(_))
    assert_true(@eval.feel_eval(original.text()).equals(original))
  }
  assert_eq(@eval.feel_eval("(>=2)").text(), "[2..)")
  assert_eq(@eval.feel_eval("[\"a\"..\"b\"]").text(), "[\"a\"..\"b\"]")
}
