///|
fn main {
  let result = @moondmn.feel_eval("sum([1, 2, 3]) * 2") catch {
    @types.Failure(_, _, _, message) => "error: " + message
  }
  println(result)
}
