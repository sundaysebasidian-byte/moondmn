///|
test "month zero preserves both extreme years" {
  for text in ["999999999-12-31", "-999999999-01-31"] {
    inspect(
      @types.date_add_months(@types.parse_date(text), 0).text() == text,
      content="true",
    )
  }
}

///|
test "month arithmetic rejects crossing either year boundary" {
  let upper = try {
    ignore(@types.date_add_months(@types.parse_date("999999999-12-31"), 1))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  let lower = try {
    ignore(@types.date_add_months(@types.parse_date("-999999999-01-31"), -1))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(upper, content="E_DATE_RANGE")
  inspect(lower, content="E_DATE_RANGE")
}

///|
test "months use floor division across year zero and clamp month ends" {
  inspect(
    @types.date_add_months(@types.parse_date("0000-01-31"), -1).text(),
    content="-0001-12-31",
  )
  inspect(
    @types.date_add_months(@types.parse_date("-0001-12-31"), 1).text(),
    content="0000-01-31",
  )
  inspect(
    @types.date_add_months(@types.parse_date("2024-01-31"), 1).text(),
    content="2024-02-29",
  )
  inspect(
    @types.date_add_months(@types.parse_date("2023-03-31"), -1).text(),
    content="2023-02-28",
  )
  inspect(
    @types.date_add_months(@types.parse_date("-0004-01-31"), 1).text(),
    content="-0004-02-29",
  )
}
