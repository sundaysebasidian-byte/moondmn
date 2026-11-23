///|
test "Decimal uses half-even ties at negative scales and enforces its scale domain" {
  assert_eq(@eval.feel_eval("decimal(145,-1)").text(), "140")
  assert_eq(@eval.feel_eval("decimal(155,-1)").text(), "160")
  assert_eq(@eval.feel_eval("decimal(-145,-1)").text(), "-140")
  assert_eq(@eval.feel_eval("decimal(-155,-1)").text(), "-160")
  assert_eq(@eval.feel_eval("decimal(149,-2)").text(), "100")
  assert_eq(@eval.feel_eval("decimal(1,-6112)").text(), "null")
  assert_eq(@eval.feel_eval("decimal(1,6177)").text(), "null")
  assert_eq(@eval.feel_eval("decimal(1,-6111)").text(), "0")
  assert_eq(@eval.feel_eval("decimal(2.5,0)").text(), "2")
  assert_eq(@eval.feel_eval("decimal(2.5,6176)").text(), "2.5")
}
