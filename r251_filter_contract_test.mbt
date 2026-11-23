///|
test "r251 filter applies a host predicate once per item in FEEL and boxed form" {
  let host = Map([])
  let mut calls = 0
  @moondmn.register_external(host, "Example", "keep(number)", args => {
    calls += 1
    if args[0] is Number(n) {
      @types.Boolean(n.compare(@types.decimal_int(2)) >= 0)
    } else {
      @types.Boolean(false)
    }
  })
  let predicate = "(function(n:number) external {java:{class:\"Example\", method signature:\"keep(number)\"}})(item)"
  assert_eq(@moondmn.feel_eval("[1,2,3][" + predicate + "]", host~), "[2,3]")
  let feel_calls = calls
  calls = 0
  let xml = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/' namespace='urn:root'><decision name='D'><filter><in><literalExpression><text>[1,2,3]</text></literalExpression></in><match><literalExpression><text>" +
    predicate +
    "</text></literalExpression></match></filter></decision></definitions>"
  assert_eq(
    @moondmn.evaluate_decision(@moondmn.parse_model(xml), "D", "{}", host~),
    "[2,3]",
  )
  assert_eq((feel_calls, calls), (3, 3))
  assert_eq(@moondmn.feel_eval("[1,2,3][-1]"), "3")
}
