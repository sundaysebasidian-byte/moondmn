///|
test "Default uppercase handles Unicode simple mappings and full expansions" {
  assert_eq(@eval.feel_eval("upper case(\"Straße ﬃ àς𐐨\")").text(), "STRASSE FFI ÀΣ𐐀")
  assert_eq(@eval.feel_eval("upper case(\"量化123😀\")").text(), "量化123😀")
  assert_eq(@eval.feel_eval("upper case(\"i\")").text(), "I")
  assert_eq(@eval.feel_eval("upper case(null)").text(), "null")
}
