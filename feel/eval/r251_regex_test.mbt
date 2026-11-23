///|
test "r251 XPath digit and word shorthands follow Unicode character classes" {
  assert_eq(@eval.feel_eval("matches(\"١𞥐4\",\"^\\d+$\")").text(), "true")
  assert_eq(@eval.feel_eval("matches(\"١\",\"^\\D$\")").text(), "false")
  assert_eq(@eval.feel_eval("matches(\"³\",\"^\\d$\")").text(), "false")
  assert_eq(
    @eval.feel_eval("matches(\"汉🦊́7\",\"^\\w+$\")").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("matches(\"_\",\"^\\W$\")").text(), "true")
  assert_eq(@eval.feel_eval("matches(\"A\",\"^\\W$\")").text(), "false")
  assert_eq(@eval.feel_eval("replace(\"a١b\",\"[\\d]\",\"X\")").text(), "aXb")
}

///|
test "r251 XPath XML name escapes distinguish initial and continuation characters" {
  assert_eq(
    @eval.feel_eval("matches(\"ns:标签-2\",\"^\\i\\c*$\")").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("matches(\"5name\",\"^\\i\\c*$\")").text(), "false")
  assert_eq(@eval.feel_eval("matches(\"á\",\"^\\i\\c*$\")").text(), "true")
  assert_eq(
    @eval.feel_eval("matches(\"𐐀name\",\"^\\i\\c*$\")").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("matches(\"5\",\"^\\I$\")").text(), "true")
  assert_eq(@eval.feel_eval("matches(\"^\",\"^\\C$\")").text(), "true")
  assert_eq(@eval.feel_eval("matches(\"·\",\"^[\\c-[\\i]]$\")").text(), "true")
}
