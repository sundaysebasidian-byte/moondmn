///|
test "Range time literals classify the ISO prefix rather than zone letters" {
  assert_eq(@eval.feel_eval("range(\"[ @\\\"10:00:00@Asia/Tokyo\\\"..@\\\"11:00:00@Asia/Tokyo\\\" ]\").end").text(), "11:00:00@Asia/Tokyo")
  assert_eq(@eval.feel_eval("range(\"[ @\\\"2024-01-02T10:00:00Z\\\"..@\\\"2024-01-03T10:00:00Z\\\" ]\").start").text(), "2024-01-02T10:00:00Z")
  assert_eq(@eval.feel_eval("range(\"[ @\\\"10:00:00@Not/AZone\\\"..@\\\"11:00:00@Not/AZone\\\" ]\")").text(), "null")
}
