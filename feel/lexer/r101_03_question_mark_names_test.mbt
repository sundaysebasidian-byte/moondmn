///|
test "Names beginning with a question mark are complete identifiers" {
  let tokens = @lexer.lex("?price + ?foo2", [])
  assert_eq(tokens[0].text, "?price")
  assert_eq(tokens[0].kind, "name")
  assert_eq(tokens[1].text, "+")
  assert_eq(tokens[2].text, "?foo2")
  assert_eq(@lexer.lex("?", [])[0].text, "?")
  assert_eq(@lexer.lex("?Alpha beta", ["?Alpha beta"])[0].text, "?Alpha beta")
  assert_eq(@lexer.lex("?price", ["?price"])[0].text, "?price")
}
