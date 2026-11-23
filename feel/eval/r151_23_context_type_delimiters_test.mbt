///|
test "Context type declarations require comma-separated field specs" {
  let invalid = [
    "{a:1,b:2} instance of context<a:number b:number>", "{a:1} instance of context<a:number,>",
  ]
  for expr in invalid {
    let rejected = try {
      ignore(@eval.feel_eval(expr))
      false
    } catch {
      @types.Failure("E_PARSE", _, _, _) => true
      e => raise e
    }
    assert_true(rejected)
  }
  assert_eq(
    @eval.feel_eval("{a:1,b:2} instance of context<a:number,b:number>").text(),
    "true",
  )
}
