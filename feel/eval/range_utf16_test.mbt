///|
test "textual string ranges split both bounds at a UTF-16 delimiter offset" {
  for
    expression in [
      "range(\"[\\\"a\\\"..\\\"c\\\"]\") = [\"a\"..\"c\"]", "range(\"[\\\"😀a\\\"..\\\"😀z\\\"]\") = [\"😀a\"..\"😀z\"]",
      "\"😀m\" in range(\"(\\\"😀a\\\"..\\\"😀z\\\"]\")",
    ] {
    inspect(@eval.feel_eval(expression).text(), content="true")
  }
}
