///|
test "R1 I3 signed exponent and decimal128 limits" {
  inspect(
    @types.decimal("1e34").text(),
    content="10000000000000000000000000000000000",
  )
  inspect(@types.decimal("1e6144").text().length(), content="6145")
  inspect(@types.decimal("1e-6176").text().length(), content="6178")
  inspect(
    @types.decimal("-1e34").compare(@types.decimal("-10e33")),
    content="0",
  )
  inspect(
    @types.decimal("1e34")
    .add(@types.decimal("1"))
    .compare(@types.decimal("1e34")),
    content="0",
  )
  for
    source in ["1e6145", "-1e6145", "99999999999999999999999999999999999e6111"] {
    let code = try {
      ignore(@types.decimal(source))
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_DECIMAL_RANGE")
  }
}

///|
test "R1 I3 subnormal half even rounding and arithmetic" {
  inspect(@types.decimal("5e-6177").text(), content="0")
  inspect(
    @types.decimal("15e-6177").compare(@types.decimal("2e-6176")),
    content="0",
  )
  inspect(
    @types.decimal("25e-6177").compare(@types.decimal("2e-6176")),
    content="0",
  )
  inspect(
    @types.decimal("-35e-6177").compare(@types.decimal("-4e-6176")),
    content="0",
  )
  inspect(
    @types.decimal("1e-6176").multiply(@types.decimal("0.1")).text(),
    content="0",
  )
  inspect(
    @types.decimal("1e-6000")
    .divide(@types.decimal("1e100"))
    .compare(@types.decimal("1e-6100")),
    content="0",
  )
  inspect(
    @types.decimal("1e4000")
    .divide(@types.decimal("1e-1000"))
    .compare(@types.decimal("1e5000")),
    content="0",
  )
  inspect(
    @types.decimal("1e34").modulo(@types.decimal("3")).text(),
    content="1",
  )
}

///|
test "R1 I3 34 digits and invalid exponent" {
  inspect(
    @types.decimal("1").divide(@types.decimal("3")).text(),
    content="0.3333333333333333333333333333333333",
  )
  inspect(
    @types.decimal("1.2345678901234567890123456789012345").text(),
    content="1.234567890123456789012345678901234",
  )
  inspect(
    @types.decimal("1.2345678901234567890123456789012355").text(),
    content="1.234567890123456789012345678901236",
  )
  for source in ["1e", "1e+", "1e-"] {
    let code = try {
      ignore(@types.decimal(source))
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_DECIMAL_SYNTAX")
  }
}
