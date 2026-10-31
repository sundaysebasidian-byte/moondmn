///|
test "extreme month arithmetic preserves identity through the JSON facade" {
  inspect(
    @moondmn.feel_eval("string(date(\"999999999-12-31\") + duration(\"P0M\"))"),
    content="\"999999999-12-31\"",
  )
  inspect(
    @moondmn.feel_eval("string(date(\"-999999999-01-31\") + duration(\"P0M\"))"),
    content="\"-999999999-01-31\"",
  )
  for
    source in [
      "date(\"999999999-12-31\") + duration(\"P1M\")", "date(\"-999999999-01-31\") - duration(\"P1M\")",
    ] {
    let code = try {
      ignore(@moondmn.feel_eval(source))
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_DATE_RANGE")
  }
}

///|
test "full date span is representable as a year month duration" {
  inspect(
    @moondmn.feel_eval(
      "string(years and months duration(date(\"-999999999-01-01\"),date(\"999999999-01-01\")))",
    ),
    content="\"P1999999998Y\"",
  )
  inspect(
    @moondmn.feel_eval(
      "string(years and months duration(date(\"999999999-01-01\"),date(\"-999999999-01-01\")))",
    ),
    content="\"-P1999999998Y\"",
  )
  inspect(
    @moondmn.feel_eval(
      "string(date(\"-999999999-01-01\") + duration(\"P1999999998Y\"))",
    ),
    content="\"999999999-01-01\"",
  )
}

///|
test "year month addition subtraction and scaling do not narrow total months" {
  inspect(
    @moondmn.feel_eval("string(duration(\"P200000000Y\") * 10)"),
    content="\"P2000000000Y\"",
  )
  inspect(
    @moondmn.feel_eval("string(duration(\"P2000000000Y\") / 10)"),
    content="\"P200000000Y\"",
  )
  inspect(
    @moondmn.feel_eval(
      "string(duration(\"P2000000000Y\") - duration(\"-P100000000Y\"))",
    ),
    content="\"P2100000000Y\"",
  )
  inspect(
    @moondmn.feel_eval(
      "string(duration(\"P2000000000Y\") + duration(\"-P2000000000Y\"))",
    ),
    content="\"P0M\"",
  )
  inspect(
    @moondmn.feel_eval("string(duration(\"P200000000Y\") * -10)"),
    content="\"-P2000000000Y\"",
  )
  for
    source in [
      "duration(\"P2000000000Y\") * 2", "duration(\"P2000000000Y\") / 0.1", "duration(\"P2000000000Y\") + duration(\"P2000000000Y\")",
    ] {
    let code = try {
      ignore(@moondmn.feel_eval(source))
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_DURATION_RANGE")
  }
}

///|
test "full date and datetime differences retain exact days" {
  inspect(
    @moondmn.feel_eval(
      "date and time(\"999999999-12-31T01:00:00+01:00\") = date and time(\"999999999-12-31T00:00:00Z\")",
    ),
    content="true",
  )
  inspect(
    @moondmn.feel_eval(
      "string(date(\"999999999-12-31\") - date(\"-999999999-01-01\"))",
    ),
    content="\"P730484999633D\"",
  )
  inspect(
    @moondmn.feel_eval(
      "string(date and time(\"999999999-12-31T00:00:00Z\") - date and time(\"-999999999-01-01T00:00:00Z\"))",
    ),
    content="\"P730484999633D\"",
  )
  inspect(
    @moondmn.feel_eval(
      "date and time(\"999999999-12-31T00:00:00Z\") > date and time(\"2000-01-01T00:00:00Z\")",
    ),
    content="true",
  )
  inspect(
    @moondmn.feel_eval(
      "string(date and time(\"1677-09-21T00:12:43.145224192Z\") - date and time(\"2262-04-11T23:47:16.854775807Z\"))",
    ),
    content="\"-P213503DT23H34M33.709551615S\"",
  )
}

///|
test "large day durations check date bounds before epoch conversion" {
  for
    source in [
      "date(\"2000-01-01\") + duration(\"P9223372036854775807D\")", "date(\"2000-01-01\") - duration(\"P9223372036854775807DT1S\")",
      "date and time(\"2000-01-01T00:00:00\") + duration(\"P9223372036854775807D\")",
      "date and time(\"999999999-12-31T23:59:59Z\") + duration(\"PT1S\")",
    ] {
    let code = try {
      ignore(@moondmn.feel_eval(source))
      "success"
    } catch {
      e => @types.error_code(e)
    }
    inspect(code, content="E_DATE_RANGE")
  }
}

///|
test "day duration scaling and clock modulo keep wide intermediates" {
  inspect(
    @moondmn.feel_eval(
      "duration(\"P10000000000D\") / duration(\"P1000000000D\")",
    ),
    content="10",
  )
  inspect(
    @moondmn.feel_eval("duration(\"P2000000000Y\") / duration(\"P200000000Y\")"),
    content="10",
  )
  inspect(
    @moondmn.feel_eval("string(duration(\"P1000000000D\") * 10)"),
    content="\"P10000000000D\"",
  )
  inspect(
    @moondmn.feel_eval("string(duration(\"P10000000000D\") / 10)"),
    content="\"P1000000000D\"",
  )
  inspect(
    @moondmn.feel_eval(
      "string(time(\"23:59:59\") + duration(\"P9223372036854775807DT1S\"))",
    ),
    content="\"00:00:00\"",
  )
  let code = try {
    ignore(@moondmn.feel_eval("duration(\"P9223372036854775807D\") * 2"))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_DURATION_RANGE")
  inspect(
    @moondmn.feel_eval("time(0,0,0,duration(\"PT999999999999999999H\"))"),
    content="null",
  )
}
