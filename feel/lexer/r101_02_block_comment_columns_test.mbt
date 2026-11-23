///|
test "Block comments preserve the token column after skipped text" {
  let x = @lexer.lex("/*x*/ 12", [])[0]
  assert_eq(x.line, 1)
  assert_eq(x.column, 7)
  let y = @lexer.lex("a/*x\nz*/b", [])[1]
  assert_eq(y.line, 2)
  assert_eq(y.column, 4)
  let z = @lexer.lex("a/**/😀", [])[1]
  assert_eq(z.column, 6)
}
