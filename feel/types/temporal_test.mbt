///|
test "leap" {
  inspect(@types.parse_date("2024-02-29").text(), content="2024-02-29")
}

///|
test "utc" {
  inspect(@types.parse_time("12:30:00Z").text(), content="12:30:00Z")
}

///|
test "offset" {
  inspect(@types.parse_time("12:30:00+05:30").text(), content="12:30:00+05:30")
}

///|
test "fraction" {
  inspect(@types.parse_time("12:30:00.123").text(), content="12:30:00.123")
}

///|
test "datetime" {
  inspect(
    @types.parse_datetime("2024-02-29T12:30:00Z").text(),
    content="2024-02-29T12:30:00Z",
  )
}

///|
test "nonleap" {
  let failed = try {
    ignore(@types.parse_date("2023-02-29"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "month" {
  let failed = try {
    ignore(@types.parse_date("2024-13-01"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "day zero" {
  let failed = try {
    ignore(@types.parse_date("2024-01-00"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "hour" {
  let failed = try {
    ignore(@types.parse_time("25:00:00"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "minute" {
  let failed = try {
    ignore(@types.parse_time("12:60:00"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "datetime separator" {
  let failed = try {
    ignore(@types.parse_datetime("2024-01-01 12:00:00"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "duration invalid" {
  let failed = try {
    ignore(@types.parse_duration("Pwrong"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}
