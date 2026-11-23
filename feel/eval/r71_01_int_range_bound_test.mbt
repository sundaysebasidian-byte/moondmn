///|
test "Integer range iteration stops on both Int32 endpoints" {
  assert_eq(
    @eval.feel_eval("(for i in 2147483647..2147483647 return i) = [2147483647]").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "(for i in 2147483646..2147483647 return i) = [2147483646,2147483647]",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "(for i in -2147483647..-2147483648 return i) = [-2147483647,-2147483648]",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("(for i in 1..-1 return i) = [1,0,-1]").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("(for i in -1..1 return i) = [-1,0,1]").text(),
    "true",
  )
}
