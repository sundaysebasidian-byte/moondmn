///|
test "Sorting a descending FEEL list stays within a logarithmic comparison budget" {
  let calls = Ref(0)
  let scope : Map[String, @types.Value] = Map([])
  scope["beforeItem"] = @types.Function({
    name: "beforeItem",
    params: ["a", "b"],
    callback: xs => {
      calls.val += 1
      Boolean(@types.compare_values(xs[0], xs[1]) < 0)
    },
  })
  let output = @eval.feel_eval(
    "sort(for i in 512..1 return i,beforeItem)",
    ctx=scope,
  )
  assert_eq(output.text(), @eval.feel_eval("for i in 1..512 return i").text())
  assert_true(calls.val <= 512 * 9)
  assert_eq(
    @eval.feel_eval(
      "sort([{k:1,v:2},{k:1,v:1},{k:0,v:3}],function(a,b) a.k < b.k).v",
    ).text(),
    "[3, 2, 1]",
  )
  assert_eq(@eval.feel_eval("sort([3,2,1],function(a,b) 0)").text(), "null")
}
