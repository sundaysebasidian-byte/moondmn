///|
test "median does not sum the entire list" {
  for
    expression in [
      "median([1, 9e6144, 9e6144]) = 9e6144", "median([-9e6144, -9e6144, -1]) = -9e6144",
      "median([8, 2, 5, 3, 4]) = 4", "median([6, 1, 2, 3]) = 2.5", "sum([8, 2, 5, 3, 4]) = 22",
    ] {
    inspect(@eval.feel_eval(expression).text(), content="true")
  }
}
