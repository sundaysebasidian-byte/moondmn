///|
test "FEEL comparison and subtraction use dated offsets" {
  inspect(
    @moondmn.feel_eval(
      "date and time(\"2024-03-10T00:30:00@America/New_York\") = date and time(\"2024-03-10T05:30:00Z\")",
    ),
    content="true",
  )
  inspect(
    @moondmn.feel_eval(
      "date and time(\"2024-01-01T00:00:00@America/Mexico_City\") - date and time(\"2024-01-01T06:00:00Z\")",
    ),
    content="\"P0D\"",
  )
}

///|
test "duration crosses spring DST by the elapsed instant" {
  inspect(
    @moondmn.feel_eval(
      "string(date and time(\"2024-03-10T01:30:00@America/New_York\") + duration(\"PT1H\"))",
    ),
    content="\"2024-03-10T03:30:00@America/New_York\"",
  )
}

///|
test "FEEL equality resolves after transition and keeps fractions" {
  inspect(
    @moondmn.feel_eval(
      "@\"2024-03-10T03:00:00@America/New_York\" = @\"2024-03-10T07:00:00Z\"",
    ),
    content="true",
  )
  inspect(
    @moondmn.feel_eval(
      "@\"2024-11-03T02:00:00@America/New_York\" = @\"2024-11-03T07:00:00Z\"",
    ),
    content="true",
  )
  inspect(
    @moondmn.feel_eval(
      "@\"2024-03-10T03:00:00.1@America/New_York\" = @\"2024-03-10T07:00:00.2Z\"",
    ),
    content="false",
  )
  inspect(
    @moondmn.feel_eval(
      "time(\"10:30:00@Europe/Paris\") = time(\"10:30:00@Europe/Paris\")",
    ),
    content="true",
  )
  inspect(
    @moondmn.feel_eval(
      "string(@\"2024-03-10T03:00:00@America/New_York\".time offset)",
    ),
    content="\"-PT4H\"",
  )
}

///|
test "numeric time constructors keep fractional seconds" {
  inspect(
    @moondmn.feel_eval("string(time(12,59,1.3,duration(\"-PT1H\")))"),
    content="\"12:59:01.3-01:00\"",
  )
  inspect(
    @moondmn.feel_eval("@\"2024-01-01T12:00:00\".time offset"),
    content="null",
  )
}

///|
test "calendar arithmetic does not construct a DST gap" {
  let code = try {
    ignore(
      @moondmn.feel_eval("@\"2024-02-10T02:30:00@America/New_York\" + @\"P1M\""),
    )
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_ZONE_GAP")
  inspect(
    @moondmn.feel_eval(
      "string(@\"2024-10-03T01:30:00@America/New_York\" + @\"P1M\")",
    ),
    content="\"2024-11-03T01:30:00@America/New_York\"",
  )
}

///|
test "proleptic dates cannot index weekday names below zero" {
  inspect(
    @moondmn.feel_eval("day of week(date(\"-2021-01-02\"))"),
    content="\"Tuesday\"",
  )
  for year in [-999999999, -2021, -1, 0, 1, 1969, 999999999] {
    for day in [1, 2, 3, 4, 5, 6, 7] {
      let date = @types.date_of(year, 1, day)
      assert_true(date.weekday() >= 1 && date.weekday() <= 7)
      inspect(
        @types.civil_from_days(date.ordinal()).text() == date.text(),
        content="true",
      )
    }
  }
}
