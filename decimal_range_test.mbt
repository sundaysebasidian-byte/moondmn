///|
test "FEEL finite overflow is null" {
  inspect(@moondmn.feel_eval("1e6144 * 10"), content="null")
  inspect(@moondmn.feel_eval("1e-6176 / 10"), content="0")
}
