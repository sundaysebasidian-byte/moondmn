///|
test "List built-ins accept the standard named list parameter" {
  assert_eq(@eval.feel_eval("count(list:[1,[2,3],null])").text(), "3")
  assert_eq(@eval.feel_eval("min(list:[4,-3,6])").text(), "-3")
  assert_eq(@eval.feel_eval("max(list:[4,-3,6])").text(), "6")
  assert_eq(@eval.feel_eval("sum(list:[3,5])").text(), "8")
  assert_eq(@eval.feel_eval("mean(list:[2,10,12])").text(), "8")
  assert_eq(@eval.feel_eval("reverse(list:[4,6,9])").text(), "[9, 6, 4]")
  assert_eq(
    @eval.feel_eval("distinct values(list:[3,1,3,2,1])").text(),
    "[3, 1, 2]",
  )
  assert_eq(
    @eval.feel_eval("flatten(list:[[1],[2,[3]],4])").text(),
    "[1, 2, 3, 4]",
  )
  assert_eq(@eval.feel_eval("sum(sum:[3,5])").text(), "8")
  assert_eq(@eval.feel_eval("sum([3,5])").text(), "8")
  assert_eq(@eval.feel_eval("sum(list:[3,5],sum:[1])").text(), "null")
  assert_eq(@eval.feel_eval("sum(list:[3,5],list:[1])").text(), "null")
  assert_eq(@eval.feel_eval("sum(xs:[3,5])").text(), "null")
  assert_eq(@eval.feel_eval("sum(list:[])").text(), "null")
  assert_eq(@eval.feel_eval("count(list:[])").text(), "0")
  assert_eq(
    @eval.feel_eval("count(list:null) = count(count:null)").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("{sum: function(list) list, value: sum(list:[3,5])}.value").text(),
    "[3, 5]",
  )
  let wrong_name_rejected = try {
    ignore(
      @eval.feel_eval("{sum: function(sum) sum, value: sum(list:[3,5])}.value"),
    )
    false
  } catch {
    @types.Failure("E_ARITY", _, _, _) => true
    e => raise e
  }
  assert_true(wrong_name_rejected)
}
