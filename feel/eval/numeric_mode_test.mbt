///|
test "numeric mode counts equal decimals and returns ascending ties" {
  for
    expression in [
      "mode([6, 1, 9, 6, 1]) = [1, 6]", "mode([3.1, 2.00, 2.0, 3.1, -5, -5]) = [-5, 2, 3.1]",
      "mode([3, 2.00, 2.0]) = [2]", "mode([4, 2, -1, 3]) = [-1, 2, 3, 4]", "mode([]) = []",
    ] {
    inspect(@eval.feel_eval(expression).text(), content="true")
  }
  inspect(@eval.feel_eval("mode([1, null])").text(), content="null")
}
