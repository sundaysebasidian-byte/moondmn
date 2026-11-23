///|
test "Comments end at FEEL line breaks and CRLF counts as one line" {
  for ending in ["\r", "\n", "\r\n"] {
    let line = @lexer.lex("//ignore" + ending + "42", [])[0]
    assert_eq(line.text, "42")
    assert_eq(line.line, 2)
    assert_eq(line.column, 1)
  }
  for c in [11, 12] {
    let tokens = @lexer.lex(
      "1 // ignored" + c.unsafe_to_char().to_string() + " + 2",
      [],
    )
    assert_eq(tokens.length(), 2)
    assert_eq(tokens[0].text, "1")
    assert_eq(tokens[1].kind, "eof")
    assert_eq(tokens[1].line, 1)
  }
  let end = @lexer.lex("//ignore", [])[0]
  assert_eq(end.column, 9)
  let block = @lexer.lex("/*note\r\nx*/ a", [])[0]
  assert_eq(block.line, 2)
  assert_eq(block.column, 5)
}
