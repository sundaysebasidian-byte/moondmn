///|
test "escaped newline" {
  inspect(@lexer.lex("\"a\\nb\"", [])[0].text, content="a\nb")
}

///|
test "unicode" {
  inspect(@lexer.lex("\"😀\"", [])[0].text, content="😀")
}

///|
test "comment" {
  inspect(@lexer.lex("/*x*/ 12", [])[0].text, content="12")
}

///|
test "line comment" {
  inspect(@lexer.lex("//x\n12", [])[0].text, content="12")
}

///|
test "scientific" {
  inspect(@lexer.lex("1e-2", [])[0].text, content="1e-2")
}

///|
test "unterminated comment" {
  let failed = try {
    ignore(@lexer.lex("/*", []))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "unterminated string" {
  let failed = try {
    ignore(@lexer.lex("\"x", []))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "regex escape preservation" {
  inspect(@lexer.lex("\"\\q\"", [])[0].text, content="\\q")
}
