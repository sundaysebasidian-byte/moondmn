///|
test "epoch days reject Int64 extremes before calendar conversion" {
  for days in [-9223372036854775808L, 9223372036854775807L] {
    let code = try {
      ignore(@types.civil_from_days(days))
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_DATE_RANGE")
  }
  for text in ["-999999999-01-01", "999999999-12-31", "0000-02-29"] {
    let date = @types.parse_date(text)
    inspect(
      @types.civil_from_days(date.ordinal()).text() == text,
      content="true",
    )
    inspect(@types.date_add_days(date, 0L).text() == text, content="true")
    inspect(date.weekday() >= 1 && date.weekday() <= 7, content="true")
    inspect(
      date.week_of_year() >= 1 && date.week_of_year() <= 53,
      content="true",
    )
    inspect(
      date.day_of_year() >= 1 && date.day_of_year() <= 366,
      content="true",
    )
  }
}

///|
test "day addition checks before summing large offsets" {
  for days in [-9223372036854775808L, 9223372036854775807L] {
    let code = try {
      ignore(@types.date_add_days(@types.parse_date("2000-01-01"), days))
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_DATE_RANGE")
  }
  let code = try {
    ignore(@types.date_add_days(@types.parse_date("999999999-12-31"), 1L))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_DATE_RANGE")
}

///|
test "nanosecond instants do not wrap past their legacy Int64 capacity" {
  let upper = @types.parse_datetime("2262-04-11T23:47:16.854775807Z")
  let lower = @types.parse_datetime("1677-09-21T00:12:43.145224192Z")
  inspect(upper.instant(), content="9223372036854775807")
  inspect(lower.instant(), content="-9223372036854775808")
  for
    text in [
      "2262-04-11T23:47:16.854775808Z", "1677-09-21T00:12:43.145224191Z", "999999999-12-31T00:00:00Z",
    ] {
    let code = try {
      ignore(@types.parse_datetime(text).instant())
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_DATE_RANGE")
  }
  inspect(
    @types.parse_datetime("999999999-12-31T00:00:00Z").epoch_nanos() >
    upper.epoch_nanos(),
    content="true",
  )
}

///|
test "clock and timezone products stay bounded for validated inputs" {
  inspect(@types.parse_time("24:00:00").seconds(), content="86400000000000")
  inspect(
    @types.make_time(23, 59, 59, 999999999, @types.Fixed(-50400)).seconds(),
    content="86399999999999",
  )
  let code = try {
    ignore(@types.make_time(0, 0, 0, 0, @types.Fixed(2147483647)))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_TIME_INVALID")
  for nanos in [-1N, 4133980800000000000N] {
    let code = try {
      ignore(@types.datetime_from_instant(nanos, @types.Fixed(0)))
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_ZONE_RANGE")
  }
}

///|
test "ordinal and weekdays agree with independent Gregorian boundary values" {
  let lower = @types.parse_date("-999999999-01-01")
  let upper = @types.parse_date("999999999-12-31")
  inspect(lower.ordinal(), content="-365243219162")
  inspect(upper.ordinal(), content="365241780471")
  inspect(lower.weekday(), content="1")
  inspect(upper.weekday(), content="5")
  let code = try {
    ignore(@types.date_add_days(lower, -1L))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_DATE_RANGE")
  inspect(
    @types.days_from_civil(-2147483648, 1, 1) < lower.ordinal(),
    content="true",
  )
  inspect(
    @types.days_from_civil(2147483647, 1, 1) > upper.ordinal(),
    content="true",
  )
}
