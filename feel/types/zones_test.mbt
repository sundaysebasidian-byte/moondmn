///|
fn same_instant(
  local_time : String,
  utc : String,
) -> Bool raise @types.EngineError {
  @types.parse_datetime(local_time).instant() ==
  @types.parse_datetime(utc).instant()
}

///|
test "New York spring transition resolves at the actual hour" {
  inspect(
    same_instant("2024-03-10T00:30:00@America/New_York", "2024-03-10T05:30:00Z"),
    content="true",
  )
  inspect(
    same_instant("2024-03-10T01:59:59@America/New_York", "2024-03-10T06:59:59Z"),
    content="true",
  )
  inspect(
    same_instant("2024-03-10T03:00:00@America/New_York", "2024-03-10T07:00:00Z"),
    content="true",
  )
  let code = try {
    ignore(@types.parse_datetime("2024-03-10T02:30:00@America/New_York"))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_ZONE_GAP")
}

///|
test "overlaps use the earlier instant" {
  inspect(
    same_instant("2024-11-03T01:30:00@America/New_York", "2024-11-03T05:30:00Z"),
    content="true",
  )
  inspect(
    same_instant("2024-11-03T02:00:00@America/New_York", "2024-11-03T07:00:00Z"),
    content="true",
  )
  inspect(
    same_instant("2024-10-27T02:30:00@Europe/Paris", "2024-10-27T00:30:00Z"),
    content="true",
  )
}

///|
test "Mexico southern hemisphere and fixed zones" {
  inspect(
    same_instant(
      "2024-01-01T00:00:00@America/Mexico_City", "2024-01-01T06:00:00Z",
    ),
    content="true",
  )
  inspect(
    same_instant("2024-10-06T01:59:59@Australia/Sydney", "2024-10-05T15:59:59Z"),
    content="true",
  )
  inspect(
    same_instant("2024-10-06T03:00:00@Australia/Sydney", "2024-10-05T16:00:00Z"),
    content="true",
  )
  inspect(
    same_instant("2024-01-01T09:00:00@Asia/Tokyo", "2024-01-01T00:00:00Z"),
    content="true",
  )
}

///|
test "unsupported years and zones are explicit" {
  let zone = try {
    ignore(@types.parse_datetime("2024-01-01T00:00:00@Mars/Base"))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(zone, content="E_ZONE_UNSUPPORTED")
  let year = try {
    ignore(
      @types.parse_datetime("1960-01-01T00:00:00@America/New_York").instant(),
    )
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(year, content="E_ZONE_RANGE")
}
