///|
test "R1 I5 FEEL comparison and subtraction use dated offsets" {
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
test "R1 I5 duration crosses spring DST by the elapsed instant" {
  inspect(
    @moondmn.feel_eval(
      "string(date and time(\"2024-03-10T01:30:00@America/New_York\") + duration(\"PT1H\"))",
    ),
    content="\"2024-03-10T03:30:00@America/New_York\"",
  )
}
