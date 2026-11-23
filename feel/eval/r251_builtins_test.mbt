///|
test "r251 standard named source for string conversion" {
  assert_eq(@eval.feel_eval("string(from:1.25)").json().stringify(), "\"1.25\"")
  assert_eq(
    @eval.feel_eval("string(string:1.25)").json().stringify(),
    "\"1.25\"",
  )
  assert_eq(@eval.feel_eval("string(from:null)").text(), "null")
  assert_eq(@eval.feel_eval("string(from:1,string:2)").text(), "null")
}

///|
test "r251 grouping and decimal separators compare after singleton adaptation" {
  assert_eq(@eval.feel_eval("number(\"1.2\",[\".\"],\".\")").text(), "null")
  assert_eq(@eval.feel_eval("number(\"1.2\",\".\",[\".\"])").text(), "null")
  assert_eq(
    @eval.feel_eval("number(\"1.234,50\",[\".\"],[\",\"])").text(),
    "1234.5",
  )
  assert_eq(@eval.feel_eval("number(\"1.2\",null,\".\")").text(), "1.2")
}

///|
test "r251 substring rejects out of domain bounds without clipping or overflow" {
  for
    source in [
      "substring(\"abc\",0)", "substring(\"abc\",-4)", "substring(\"abc\",4)", "substring(\"abc\",2.5)",
      "substring(\"abc\",2,0)", "substring(\"abc\",2,3)", "substring(\"abc\",2,2147483647)",
      "substring(\"abc\",2,2.99)", "substring(\"a😀b\",-2,2.0000000001)",
    ] {
    assert_eq(@eval.feel_eval(source).json().stringify(), "null")
  }
  assert_eq(@eval.feel_eval("substring(\"a😀b\",-2,2)").text(), "😀b")
  assert_eq(@eval.feel_eval("substring(\"abcd\",2,2.8)").text(), "bc")
}

///|
test "r251 UTC designator accepts DMN lowercase z spelling" {
  assert_eq(@eval.feel_eval("time(\"23:59:00z\")").text(), "23:59:00Z")
  assert_eq(
    @eval.feel_eval("date and time(\"2012-12-25T11:00:00z\")").text(),
    "2012-12-25T11:00:00Z",
  )
  assert_eq(@eval.feel_eval("time(\"15:00:00zX\")").text(), "null")
  assert_eq(@eval.feel_eval("time(\"15:00:00Z\")").text(), "15:00:00Z")
}

///|
test "r251 numeric time input cannot silently discard subnanosecond seconds" {
  assert_eq(@eval.feel_eval("time(10,0,1.0000000001)").text(), "null")
  assert_eq(
    @eval.feel_eval("date and time(2020,1,1,10,0,1.0000000001)").text(),
    "null",
  )
  assert_eq(
    @eval.feel_eval("time(10,0,1.0000000010)").text(),
    "10:00:01.000000001",
  )
  assert_eq(@eval.feel_eval("time(10,0,60)").text(), "null")
}

///|
test "r251 end of day date-time canonicalizes to following day before properties" {
  assert_eq(
    @eval.feel_eval("date and time(\"2024-02-29T24:00:00Z\")").text(),
    "2024-03-01T00:00:00Z",
  )
  assert_eq(
    @eval.feel_eval("date and time(date(\"2024-02-29\"),time(\"24:00:00\"))").text(),
    "2024-03-01T00:00:00",
  )
  assert_eq(
    @eval.feel_eval("date and time(\"2024-02-29T24:00:01\")").text(),
    "null",
  )
  assert_eq(
    @eval.feel_eval("date and time(\"2024-02-29T00:00:00\" )").text(),
    "2024-02-29T00:00:00",
  )
}

///|
test "r251 bounds relations accept only applicable point or interval signatures" {
  for
    source in [
      "meets(1,1)", "overlaps(2,[1..3])", "starts([1..2],1)", "coincides([1..1],1)",
      "before(null,(<5))", "before([1],(<5))", "after((>5),{k:1})",
    ] {
    assert_eq(@eval.feel_eval(source).text(), "null")
  }
  assert_eq(@eval.feel_eval("before([1..2],3)").text(), "true")
  assert_eq(@eval.feel_eval("meets([1..2],[2..3])").text(), "true")
  assert_eq(@eval.feel_eval("starts(1,[1..2])").text(), "true")
  assert_eq(@eval.feel_eval("coincides(1,1)").text(), "true")
}

///|
test "r251 unconditionally expanded lowercase follows Unicode without locale" {
  assert_eq(@eval.feel_eval("lower case(\"İ\")").text(), "i\u0307")
  assert_eq(@eval.feel_eval("lower case(\"Iẞ𐐀\")").text(), "iß𐐨")
  assert_eq(@eval.feel_eval("lower case(null)").text(), "null")
}
