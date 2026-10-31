///|
test "longest scoped name and source position" {
  let ts = @lexer.lex("Applicant Age + a-b\n>= 2", ["Applicant Age", "a-b"])
  inspect(ts[0].text, content="Applicant Age")
  inspect(ts[2].text, content="a-b")
  inspect(ts[3].line, content="2")
  assert_true(
    try {
      ignore(@lexer.lex("\"unterminated", []))
      false
    } catch {
      _ => true
    },
  )
}
