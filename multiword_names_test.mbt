///|
test "multiword and operator fields use known context keys" {
  let context = "{\"Applicant\":{\"Credit Score\":720,\"a-b\":2,\"then score\":3,\"Nested Object\":{\"Score Value\":4}}}"
  inspect(@moondmn.feel_eval("Applicant.Credit Score", context~), content="720")
  inspect(
    @moondmn.feel_eval("Applicant.a-b + Applicant.then score", context~),
    content="5",
  )
  inspect(
    @moondmn.feel_eval("Applicant.Nested Object.Score Value", context~),
    content="4",
  )
  inspect(@moondmn.feel_eval("Applicant.Missing", context~), content="null")
  let code = try {
    ignore(@moondmn.feel_eval("Applicant.Unknown Field", context~))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_UNSUPPORTED_SYNTAX")
}

///|
test "literal context names remain scoped and use longest matches" {
  inspect(@moondmn.feel_eval("{Credit Score:720}.Credit Score"), content="720")
  inspect(@moondmn.feel_eval("{a-b:2}.a-b"), content="2")
  inspect(
    @moondmn.feel_eval("{Credit:1, Credit Score:720}.Credit Score"),
    content="720",
  )
}
