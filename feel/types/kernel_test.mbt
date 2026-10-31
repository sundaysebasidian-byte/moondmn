///|
test "decimal normalize" {
  inspect(@types.decimal("001.2300").text(), content="1.23")
}

///|
test "decimal negative zero" {
  inspect(@types.decimal("-0").text(), content="0")
}

///|
test "decimal exponent" {
  inspect(@types.decimal("1e3").text(), content="1000")
}

///|
test "decimal subtract" {
  inspect(
    @types.decimal("1").add(@types.decimal("0.9").negate()).text(),
    content="0.1",
  )
}

///|
test "decimal multiply" {
  inspect(
    @types.decimal("0.2").multiply(@types.decimal("0.3")).text(),
    content="0.06",
  )
}

///|
test "decimal divide" {
  inspect(
    @types.decimal("1").divide(@types.decimal("16")).text(),
    content="0.0625",
  )
}

///|
test "decimal floor negative" {
  inspect(@types.decimal("-0.1").floor().text(), content="-1")
}

///|
test "decimal ceil positive" {
  inspect(@types.decimal("0.1").ceiling().text(), content="1")
}

///|
test "decimal truncate negative" {
  inspect(@types.decimal("-1.9").truncate().text(), content="-1")
}

///|
test "decimal half even" {
  inspect(@types.decimal("2.5").round(0).text(), content="2")
}
