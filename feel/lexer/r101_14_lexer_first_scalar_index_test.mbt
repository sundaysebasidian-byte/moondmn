///|
test "Indexed known lexemes retain longest matches and Unicode boundaries" {
  let tokens = @lexer.lex(
    "𝛼 long name + date and time + obj.𝛼 prop",
    ["𝛼", "𝛼 long name", "date", "date and time"],
    properties=["𝛼 prop"],
  )
  assert_eq(
    tokens.map(t => t.text).join("|"),
    "𝛼 long name|+|date and time|+|obj|.|𝛼 prop|",
  )
  let boundaries = @lexer.lex("dateX + date + obj.fixed name", ["date"], properties=[
    "fixed name",
  ])
  assert_eq(
    boundaries.map(t => t.text).join("|"),
    "dateX|+|date|+|obj|.|fixed name|",
  )
}
