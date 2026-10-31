///|
test "exact decimal arithmetic and limits" {
  inspect(
    @types.decimal("0.1").add(@types.decimal("0.2")).text(),
    content="0.3",
  )
  inspect(
    @types.decimal("1").divide(@types.decimal("8")).text(),
    content="0.125",
  )
  inspect(
    @types.decimal("9999999999999999999999999999999999").text(),
    content="9999999999999999999999999999999999",
  )
  let result = Ok(@types.decimal("1").divide(@types.decimal("3"))) catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

///|
test "JSON preserves authored decimal" {
  let ctx = @types.json_context("{\"n\":1234567890123456789012345678901234}")
  inspect(
    ctx["n"].json().stringify(),
    content="1234567890123456789012345678901234",
  )
}
