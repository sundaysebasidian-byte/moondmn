// Expectations follow DMN 1.5 clauses 10.3.2, 10.3.4 and 10.4.

///|
test "lexicographic strings" {
  inspect(@eval.feel_eval("\"10\" < \"8\"").json().stringify(), content="true")
  inspect(@eval.feel_eval("\"Aa\" < \"a\"").json().stringify(), content="true")
}

///|
test "boolean unary values" {
  inspect(
    @eval.feel_eval("false in (true)").json().stringify(),
    content="false",
  )
  inspect(
    @eval.feel_eval("false in ({a:true}.a)").json().stringify(),
    content="false",
  )
  inspect(
    @eval.feel_eval("false in (not({a:true}.a))").json().stringify(),
    content="true",
  )
}

///|
test "nested list membership" {
  inspect(
    @eval.feel_eval("[1,2] in [[3], [1,2]]").json().stringify(),
    content="true",
  )
  inspect(
    @eval.feel_eval("[1,3] in [[1,2]]").json().stringify(),
    content="false",
  )
}

///|
test "filter field scope" {
  inspect(
    @eval.feel_eval("[{item:2},{item:3}][item > 2].item").json().stringify(),
    content="[3]",
  )
  inspect(
    @eval.feel_eval("[{x:1},{y:2}][y > 1].y").json().stringify(),
    content="[2]",
  )
}

///|
test "invalid range iteration" {
  inspect(
    @eval.feel_eval("for x in [\"a\"..\"z\"] return x").json().stringify(),
    content="null",
  )
  inspect(
    @eval.feel_eval("for x in [2..1] return x").json().stringify(),
    content="null",
  )
}

///|
test "interval equality boundaries" {
  inspect(
    @eval.feel_eval("starts([1..3],[1..3])").json().stringify(),
    content="true",
  )
  inspect(
    @eval.feel_eval("finishes((1..3], [1..3])").json().stringify(),
    content="true",
  )
  inspect(
    @eval.feel_eval("overlaps before([1..3],(1..3])").json().stringify(),
    content="true",
  )
  inspect(
    @eval.feel_eval("overlaps before([1..3],[1..3])").json().stringify(),
    content="false",
  )
}

///|
test "left associative exponent" {
  inspect(@eval.feel_eval("2 ** 3 ** 2").json().stringify(), content="64")
}

///|
test "unicode FEEL names" {
  inspect(@eval.feel_eval("{客户: 7}.客户").json().stringify(), content="7")
}

///|
test "builtin singleton strings" {
  inspect(
    @eval.feel_eval("upper case([\"alice\"])").json().stringify(),
    content="\"ALICE\"",
  )
}

///|
test "substring fractional length" {
  inspect(
    @eval.feel_eval("substring(\"abcdef\", 2, 2.8)").json().stringify(),
    content="\"bc\"",
  )
}

///|
test "number separators" {
  inspect(
    @eval.feel_eval("number(\"1.2\", \".\", \".\")").json().stringify(),
    content="null",
  )
  inspect(
    @eval.feel_eval(
      "number(from:\"1.000,1\", decimal sep:\",\", grouping sep:\".\")",
    )
    .json()
    .stringify(),
    content="null",
  )
}

///|
test "regular expression splitting" {
  inspect(
    @eval.feel_eval("split(\"a   b\", \"\\s+\")").json().stringify(),
    content="[\"a\",\"b\"]",
  )
}

///|
test "XPath free spacing regex" {
  inspect(
    @eval.feel_eval("matches(\"a b\", \"a\\ sb\", \"x\")").json().stringify(),
    content="true",
  )
  inspect(
    @eval.feel_eval(
      "matches(\"abc\", \"\\p{ I s B a s i c L a t i n }+\", \"x\")",
    )
    .json()
    .stringify(),
    content="true",
  )
}

///|
test "date midnight and offset seconds" {
  inspect(
    @eval.feel_eval("time(date(\"2020-01-01\"))").json().stringify(),
    content="\"00:00:00Z\"",
  )
  inspect(
    @eval.feel_eval("time(12,0,0,duration(\"PT1H2M3S\"))").json().stringify(),
    content="\"12:00:00+01:02:03\"",
  )
}

///|
test "duplicate context keys" {
  inspect(@eval.feel_eval("{a:1,a:2}").json().stringify(), content="null")
}

///|
test "context put overload domains" {
  inspect(
    @eval.feel_eval("context put(context:{a:1}, key:[\"a\"], value:2)")
    .json()
    .stringify(),
    content="null",
  )
}

///|
test "nullable context fields" {
  inspect(
    @eval.feel_eval("{a:null} instance of context<a:string>").json().stringify(),
    content="true",
  )
}

///|
test "function parameter declarations" {
  inspect(
    @eval.feel_eval("(function(x:number) x)(\"bad\")").json().stringify(),
    content="null",
  )
  inspect(
    @eval.feel_eval("(function(x:number) x)([7])").json().stringify(),
    content="7",
  )
}

///|
test "zoned date subtraction" {
  inspect(
    @eval.feel_eval(
      "date(\"2020-01-02\") - date and time(\"2020-01-01T00:00:00Z\")",
    )
    .json()
    .stringify(),
    content="\"P1D\"",
  )
  inspect(
    @eval.feel_eval(
      "date(\"2020-01-02\") - date and time(\"2020-01-01T00:00:00\")",
    )
    .json()
    .stringify(),
    content="null",
  )
}

///|
test "extended date years reject leading zero" {
  inspect(
    @eval.feel_eval("date(\"02020-01-01\")").json().stringify(),
    content="null",
  )
  inspect(
    @eval.feel_eval("date and time(\"02020-01-01T00:00:00Z\")")
    .json()
    .stringify(),
    content="null",
  )
}
