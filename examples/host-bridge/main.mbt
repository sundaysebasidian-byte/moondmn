///|
fn main {
  let host = Map([])
  @moondmn.register_external(host, "Example", "echo(number)", args => args[0])
  let result = @moondmn.feel_eval(
    "(function(n: number) external {java:{class: \"Example\", method signature: \"echo(number)\"}})([42])",
    host~,
  ) catch {
    @types.Failure(code, _, _, message) => code + ": " + message
  }
  println(result)
}
