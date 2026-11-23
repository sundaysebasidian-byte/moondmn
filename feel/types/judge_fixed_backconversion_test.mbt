///|
test "Epoch conversion rejects fixed offsets outside the Time constructor domain" {
  for n in [-50401,50401,2147483647] {
    let code = try { ignore(@types.datetime_from_instant(172800000000000N,@types.Fixed(n))); "ok" } catch { e => @types.error_code(e) }
    assert_eq(code,"E_TIME_INVALID")
  }
  for n in [-50400,0,50400] {
    let nanos = 172800000000123N
    assert_eq(@types.datetime_from_instant(nanos,@types.Fixed(n)).epoch_nanos(),nanos)
  }
}
