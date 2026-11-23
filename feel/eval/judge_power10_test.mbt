///|
test "Integral exponents of signed decimal powers of ten avoid binary64 loss" {
  for (source, expected) in [("10 ** 3000 = 1e3000","true"),("10 ** -6176 = 1e-6176","true"),("(-100) ** -1001 = -1e-2002","true"),("0.01 ** -2000 = 1e4000","true"),("10 ** -6177","0"),("10 ** 6145","null"),("(-1) ** 9999999999999999999999999999999999","-1"),("(-1) ** 1e90","1"),("3 ** 4","81")] {
    assert_eq(@eval.feel_eval(source).text(),expected)
  }
}
