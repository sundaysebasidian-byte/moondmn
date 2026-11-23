///|
test "TCK duration subtypes do not silently reinterpret another family as zero" {
  for (kind, source, expected) in [("dayTimeDuration", "P1Y","E_TCK_VALUE"), ("yearMonthDuration","PT0S","E_TCK_VALUE"), ("yearMonthDuration","P0M","P0M"), ("dayTimeDuration","PT1M","PT1M"), ("duration","PT1M","PT1M")] {
    let xml = "<input xmlns:i='http://www.w3.org/2001/XMLSchema-instance'><value i:type='xs:" + kind + "'>" + source + "</value></input>"
    let result = try { @tck.value(@xml.parse(xml)).text() } catch { e => @types.error_code(e) }
    assert_eq(result,expected)
  }
}
