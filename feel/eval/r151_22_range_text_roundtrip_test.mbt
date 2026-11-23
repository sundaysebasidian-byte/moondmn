///|
test "Structural range text preserves quoted and temporal endpoints" {
  assert_eq(
    @eval.feel_eval("range(string([\"a..b\"..\"z\"])) = [\"a..b\"..\"z\"]").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "range(string([@\"2024-02-01\"..@\"2024-03-01\"])) = [@\"2024-02-01\"..@\"2024-03-01\"]",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "range(string([@\"PT1S\"..@\"PT2S\"])) = [@\"PT1S\"..@\"PT2S\"]",
    ).text(),
    "true",
  )
  assert_eq(@eval.feel_eval("range(string((1..3])) = (1..3]").text(), "true")
  assert_eq(
    @eval.feel_eval("range(string([\"a\\tb\"..\"z\"])) = [\"a\\tb\"..\"z\"]").text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "range(string([time(\"10:00:00@Asia/Tokyo\")..time(\"11:00:00@Asia/Tokyo\")])) = [time(\"10:00:00@Asia/Tokyo\")..time(\"11:00:00@Asia/Tokyo\")]",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "range(string([time(\"10:00:00\")..time(\"11:00:00\")])) = [time(\"10:00:00\")..time(\"11:00:00\")]",
    ).text(),
    "true",
  )
  assert_eq(
    @eval.feel_eval(
      "range(string([@\"2024-04-01T12:00:00@Asia/Tokyo\"..@\"2024-04-01T13:00:00@Asia/Tokyo\"])) = [@\"2024-04-01T12:00:00@Asia/Tokyo\"..@\"2024-04-01T13:00:00@Asia/Tokyo\"]",
    ).text(),
    "true",
  )
}
