///|
test "arity precedes unavailable clock and named time arithmetic is determinate" {
  for source in ["now(123)", "today(1)"] {
    assert_eq(@moondmn.feel_eval(source), "null")
  }
  assert_eq(
    @moondmn.feel_eval(
      "@\"10:10:10@Australia/Melbourne\" - @\"11:10:10@Australia/Melbourne\"",
    ),
    "\"-PT1H\"",
  )
  assert_eq(
    @moondmn.feel_eval(
      "@\"10:10:10@Australia/Melbourne\" < @\"11:10:10@Australia/Melbourne\"",
    ),
    "true",
  )
  let code = try {
    ignore(
      @moondmn.feel_eval(
        "@\"10:10:10@Australia/Melbourne\" - @\"11:10:10@Europe/Paris\"",
      ),
    )
    "OK"
  } catch {
    e => @types.error_code(e)
  }
  assert_eq(code, "E_ZONE_AMBIGUOUS")
  assert_true(@types.fail("E_TEST", "example").to_string().contains("E_TEST"))
}
