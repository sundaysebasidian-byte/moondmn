///|
test "A FEEL literal cannot contain unescaped vertical format characters" {
  for c in [10, 11, 12, 13] {
    let ch = c.unsafe_to_char().to_string()
    for input in ["\"a" + ch + "b\"", "\"a\\" + ch + "b\""] {
      let rejected = try {
        ignore(@lexer.lex(input, []))
        false
      } catch {
        @types.Failure("E_LEX", _, _, _) => true
        e => raise e
      }
      assert_true(rejected)
    }
  }
  assert_eq(@lexer.lex("\"a\\nb\"", [])[0].text, "a\nb")
}
