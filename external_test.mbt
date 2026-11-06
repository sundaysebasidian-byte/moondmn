///|
test "host bridge typed FEEL conversion and registration isolation" {
  let host = Map([])
  @moondmn.register_external(host, "Example", "twice(number)", args => {
    if args.length() != 1 {
      raise @types.fail("E_ARITY", "expected one argument")
    }
    @eval.feel_eval("n * 2", ctx=Map([("n", args[0])]))
  })
  let source = "(function(n: number) external {java:{class: \"Example\", method signature: \"twice(number)\"}})([21])"
  inspect(@moondmn.feel_eval(source, host~), content="42")
  let failure = try {
    ignore(@moondmn.feel_eval(source))
    "ok"
  } catch {
    @types.Failure(code, _, _, message) => code + ": " + message
  }
  inspect(
    failure,
    content="E_EXTERNAL_UNBOUND: unregistered external function: Example :: twice(number)",
  )
  inspect(
    @moondmn.feel_eval("(function() external {java: {class: 1}})()", host~) catch {
      e => @types.error_code(e)
    },
    content="E_EXTERNAL_DESCRIPTOR",
  )
}

///|
test "boxed Java function and BKM call host after type conversion" {
  let host = Map([])
  @moondmn.register_external(host, "Example", "echo(number)", args => args[0])
  let descriptor = "<context><contextEntry><variable name='class'/><literalExpression><text>\"Example\"</text></literalExpression></contextEntry><contextEntry><variable name='method signature'/><literalExpression><text>\"echo(number)\"</text></literalExpression></contextEntry></context>"
  let prefix = "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'>"
  let boxed = @moondmn.parse_model(
    prefix +
    "<decision id='d' name='d'><invocation><functionDefinition kind='Java'><formalParameter name='x' typeRef='number'/>" +
    descriptor +
    "</functionDefinition><binding><parameter name='x'/><literalExpression><text>[42]</text></literalExpression></binding></invocation></decision></definitions>",
  )
  inspect(@moondmn.evaluate_decision(boxed, "d", "{}", host~), content="42")
  let bkm = @moondmn.parse_model(
    prefix +
    "<businessKnowledgeModel id='b' name='echo'><encapsulatedLogic kind='Java'><formalParameter name='x' typeRef='number'/>" +
    descriptor +
    "</encapsulatedLogic></businessKnowledgeModel><decision id='d' name='d'><knowledgeRequirement><requiredKnowledge href='#b'/></knowledgeRequirement><literalExpression><text>echo([42])</text></literalExpression></decision></definitions>",
  )
  inspect(@moondmn.evaluate_decision(bkm, "d", "{}", host~), content="42")
  inspect(
    @moondmn.evaluate_decision(boxed, "d", "{}") catch {
      e => @types.error_code(e)
    },
    content="E_EXTERNAL_UNBOUND",
  )
}
