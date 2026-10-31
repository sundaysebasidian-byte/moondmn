///|
test "year month normalization and parse retain wide total months" {
  let (_, duration) = @types.parse_duration("P2000000000Y11M")
  inspect(duration.total_months(), content="24000000011")
  inspect(duration.text(), content="P2000000000Y11M")
  inspect(
    @types.DurationYM::canonical(false, 2000000000, 23).text(),
    content="P2000000001Y11M",
  )
  inspect(
    @types.duration_ym_of_months(-23999999976N).text(),
    content="-P1999999998Y",
  )
  for value in [25769803776N, -25769803776N] {
    let code = try {
      ignore(@types.duration_ym_of_months(value))
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_DURATION_RANGE")
  }
}

///|
test "duration parsers check capacity before narrowing" {
  for
    text in [
      "P2147483648Y", "-P2147483648Y", "P9223372036854775808D", "P9999999999999999999999999999999999Y",
    ] {
    let code = try {
      ignore(@types.parse_duration(text))
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_DURATION_RANGE")
  }
}

///|
test "day duration maximum normalizes exactly and overflows explicitly" {
  let max = @types.DurationDS::canonical(
    false, 9223372036854775807L, 86399999999999L,
  )
  inspect(max.text(), content="P9223372036854775807DT23H59M59.999999999S")
  inspect(max.negate().negate().text() == max.text(), content="true")
  inspect(max.subtract(max).text(), content="P0D")
  let one = @types.duration_ds_of_nanos(1N)
  let code = try {
    ignore(max.add(one))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_DURATION_RANGE")
  let code = try {
    ignore(
      @types.DurationDS::canonical(false, 9223372036854775807L, 86400000000000L),
    )
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_DURATION_RANGE")
  let code = try {
    ignore(@types.DurationDS::canonical(false, -9223372036854775808L, 0L))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_DURATION_RANGE")
}

///|
test "decimal duration units check scale before subtraction" {
  for scale in [-2147483648, 2147483647] {
    let code = try {
      ignore(@types.decimal_to_scaled(@types.decimal("1"), scale))
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_DECIMAL_RANGE")
  }
  inspect(
    @types.decimal_to_scaled(@types.decimal("1.0000000005"), 9).to_string(),
    content="1000000000",
  )
}
