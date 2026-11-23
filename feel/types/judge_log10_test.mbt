///|
test "Base-ten logarithms outside binary64 keep their decimal exponents" {
  assert_eq(@types.decimal("1e5000").log10().text(), "5000")
  assert_eq(@types.decimal("1e-6000").log10().text(), "-6000")
  assert_eq(@types.decimal("100").log10().text(), "2")
}
