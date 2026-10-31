///|
test "builtins use exact decimals and FEEL lists" {
  inspect(
    @eval.feel_eval("sum([0.1, 0.2, 0.3])").json().stringify(),
    content="0.6",
  )
  inspect(
    @eval.feel_eval("string length(\"😀a\")").json().stringify(),
    content="2",
  )
  inspect(
    @eval.feel_eval("all([true,null,false])").json().stringify(),
    content="false",
  )
  inspect(
    @eval.feel_eval("flatten([1,[2,[3]]])").json().stringify(),
    content="[1,2,3]",
  )
}
