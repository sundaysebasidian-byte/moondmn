///|
test "Integer powers round the exact result instead of rounding partial powers" {
  assert_eq(
    @eval.feel_eval(
      "1.234567890123456789**19 = 54.80050580871421338129421792793585",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval("7.321**37 = 97522551116811139221315946813052.58").text(),
    "true",
  )
  assert_eq(@eval.feel_eval("1e4000**-2 = 0").text(), "true")
  assert_eq(@eval.feel_eval("1e-4000**-1 = 1e4000").text(), "true")
  assert_eq(@eval.feel_eval("(-2)**-3 = -0.125").text(), "true")
  assert_eq(@eval.feel_eval("0**0 = 1").text(), "true")
  assert_eq(@eval.feel_eval("0**3 = 0").text(), "true")
  assert_eq(
    @eval.feel_eval("3**-100 = 1.940325217482632837588506028804650e-48").text(),
    "true",
  )
}
