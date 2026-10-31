///|
test "decimal precedence" {
  inspect(@eval.feel_eval("0.1 + 0.2 * 3").json().stringify(), content="0.7")
}

///|
test "division zero" {
  inspect(@eval.feel_eval("1/0").json().stringify(), content="null")
}

///|
test "negative index" {
  inspect(@eval.feel_eval("[1,2,3][-1]").json().stringify(), content="3")
}

///|
test "negative first" {
  inspect(@eval.feel_eval("[1,2,3][-3]").json().stringify(), content="1")
}

///|
test "index zero" {
  inspect(@eval.feel_eval("[1][0]").json().stringify(), content="null")
}

///|
test "index overflow" {
  inspect(@eval.feel_eval("[1][3]").json().stringify(), content="null")
}

///|
test "scalar filter" {
  inspect(@eval.feel_eval("100[true]").json().stringify(), content="[100]")
}

///|
test "scalar reject" {
  inspect(@eval.feel_eval("100[false]").json().stringify(), content="[]")
}

///|
test "record filter" {
  inspect(
    @eval.feel_eval("[{a:1},{a:2}][a > 1].a").json().stringify(),
    content="[2]",
  )
}

///|
test "empty filter" {
  inspect(@eval.feel_eval("[][true]").json().stringify(), content="[]")
}

///|
test "keyword string" {
  inspect(@eval.feel_eval("\"true\"").json().stringify(), content="\"true\"")
}

///|
test "null string" {
  inspect(@eval.feel_eval("\"null\"").json().stringify(), content="\"null\"")
}

///|
test "punctuation string" {
  inspect(@eval.feel_eval("\"(\"").json().stringify(), content="\"(\"")
}

///|
test "and type" {
  inspect(@eval.feel_eval("123 and true").json().stringify(), content="null")
}

///|
test "and false" {
  inspect(@eval.feel_eval("123 and false").json().stringify(), content="false")
}

///|
test "or type" {
  inspect(@eval.feel_eval("123 or false").json().stringify(), content="null")
}

///|
test "or true" {
  inspect(@eval.feel_eval("123 or true").json().stringify(), content="true")
}

///|
test "and quoted" {
  inspect(
    @eval.feel_eval("\"true\" and true").json().stringify(),
    content="null",
  )
}

///|
test "if null" {
  inspect(
    @eval.feel_eval("if null then 1 else 2").json().stringify(),
    content="2",
  )
}

///|
test "if number" {
  inspect(@eval.feel_eval("if 1 then 1 else 2").json().stringify(), content="2")
}

///|
test "list equality" {
  inspect(@eval.feel_eval("[1,2] = [1,2]").json().stringify(), content="true")
}

///|
test "context equality" {
  inspect(@eval.feel_eval("{a:1} = {a:1}").json().stringify(), content="true")
}

///|
test "between" {
  inspect(
    @eval.feel_eval("2 between 1 and 3").json().stringify(),
    content="true",
  )
}

///|
test "membership" {
  inspect(@eval.feel_eval("2 in [1..3]").json().stringify(), content="true")
}

///|
test "for range" {
  inspect(
    @eval.feel_eval("for x in 1..3 return x*2").json().stringify(),
    content="[2,4,6]",
  )
}

///|
test "every empty" {
  inspect(
    @eval.feel_eval("every x in [] satisfies false").json().stringify(),
    content="true",
  )
}

///|
test "some empty" {
  inspect(
    @eval.feel_eval("some x in [] satisfies true").json().stringify(),
    content="false",
  )
}

///|
test "lambda" {
  inspect(
    @eval.feel_eval("(function(x) x+1)(2)").json().stringify(),
    content="3",
  )
}

///|
test "context scope" {
  inspect(@eval.feel_eval("{a:1,b:a+2}.b").json().stringify(), content="3")
}

///|
test "path flatten" {
  inspect(
    @eval.feel_eval("[{a:[1,2]},{a:[3]}].a").json().stringify(),
    content="[[1,2],[3]]",
  )
}

///|
test "sum" {
  inspect(@eval.feel_eval("sum([0.1,0.2])").json().stringify(), content="0.3")
}

///|
test "product" {
  inspect(@eval.feel_eval("product([2,3,4])").json().stringify(), content="24")
}

///|
test "mean" {
  inspect(@eval.feel_eval("mean([1,2,3])").json().stringify(), content="2")
}

///|
test "median" {
  inspect(@eval.feel_eval("median([3,1,2])").json().stringify(), content="2")
}

///|
test "mode" {
  inspect(@eval.feel_eval("mode([1,2,2])").json().stringify(), content="[2]")
}

///|
test "count" {
  inspect(@eval.feel_eval("count([])").json().stringify(), content="0")
}

///|
test "min" {
  inspect(@eval.feel_eval("min([3,1])").json().stringify(), content="1")
}

///|
test "max" {
  inspect(@eval.feel_eval("max([3,1])").json().stringify(), content="3")
}

///|
test "all null" {
  inspect(
    @eval.feel_eval("all([true,null])").json().stringify(),
    content="null",
  )
}

///|
test "any false" {
  inspect(
    @eval.feel_eval("any([false,false])").json().stringify(),
    content="false",
  )
}

///|
test "abs duration" {
  inspect(
    @eval.feel_eval("abs(@\"-P2D\")").json().stringify(),
    content="\"P2D\"",
  )
}

///|
test "abs months" {
  inspect(
    @eval.feel_eval("abs(@\"-P1Y\")").json().stringify(),
    content="\"P1Y\"",
  )
}

///|
test "sqrt" {
  inspect(@eval.feel_eval("sqrt(4)").json().stringify(), content="2")
}

///|
test "sqrt domain" {
  inspect(@eval.feel_eval("sqrt(-1)").json().stringify(), content="null")
}

///|
test "exp zero" {
  inspect(@eval.feel_eval("exp(0)").json().stringify(), content="1")
}

///|
test "log one" {
  inspect(@eval.feel_eval("log(1)").json().stringify(), content="0")
}

///|
test "even" {
  inspect(@eval.feel_eval("even(4)").json().stringify(), content="true")
}

///|
test "odd" {
  inspect(@eval.feel_eval("odd(3)").json().stringify(), content="true")
}

///|
test "modulo" {
  inspect(@eval.feel_eval("modulo(-5,3)").json().stringify(), content="1")
}

///|
test "decimal ties" {
  inspect(@eval.feel_eval("decimal(1.25,1)").json().stringify(), content="1.2")
}

///|
test "round up" {
  inspect(@eval.feel_eval("round up(1.21,1)").json().stringify(), content="1.3")
}

///|
test "round negative" {
  inspect(
    @eval.feel_eval("round up(-1.21,1)").json().stringify(),
    content="-1.3",
  )
}

///|
test "round down" {
  inspect(
    @eval.feel_eval("round down(-1.29,1)").json().stringify(),
    content="-1.2",
  )
}

///|
test "half up" {
  inspect(
    @eval.feel_eval("round half up(1.25,1)").json().stringify(),
    content="1.3",
  )
}

///|
test "half down" {
  inspect(
    @eval.feel_eval("round half down(1.25,1)").json().stringify(),
    content="1.2",
  )
}

///|
test "floor" {
  inspect(@eval.feel_eval("floor(-1.2)").json().stringify(), content="-2")
}

///|
test "ceiling" {
  inspect(@eval.feel_eval("ceiling(-1.2)").json().stringify(), content="-1")
}

///|
test "number grouping" {
  inspect(
    @eval.feel_eval("number(\"1.000.000,01\",\".\",\",\")").json().stringify(),
    content="1000000.01",
  )
}

///|
test "number invalid" {
  inspect(@eval.feel_eval("number(\"abc\")").json().stringify(), content="null")
}

///|
test "number type" {
  inspect(@eval.feel_eval("number(12)").json().stringify(), content="null")
}

///|
test "string unicode" {
  inspect(
    @eval.feel_eval("string length(\"😀a\")").json().stringify(),
    content="2",
  )
}

///|
test "uppercase" {
  inspect(
    @eval.feel_eval("upper case(\"Abc\")").json().stringify(),
    content="\"ABC\"",
  )
}

///|
test "lowercase" {
  inspect(
    @eval.feel_eval("lower case(\"AbC\")").json().stringify(),
    content="\"abc\"",
  )
}

///|
test "substring" {
  inspect(
    @eval.feel_eval("substring(\"abcd\",2,2)").json().stringify(),
    content="\"bc\"",
  )
}

///|
test "substring before" {
  inspect(
    @eval.feel_eval("substring before(\"a:b\",\":\")").json().stringify(),
    content="\"a\"",
  )
}

///|
test "substring after" {
  inspect(
    @eval.feel_eval("substring after(\"a:b\",\":\")").json().stringify(),
    content="\"b\"",
  )
}

///|
test "contains" {
  inspect(
    @eval.feel_eval("contains(\"abc\",\"b\")").json().stringify(),
    content="true",
  )
}

///|
test "starts with" {
  inspect(
    @eval.feel_eval("starts with(\"abc\",\"a\")").json().stringify(),
    content="true",
  )
}

///|
test "ends with" {
  inspect(
    @eval.feel_eval("ends with(\"abc\",\"c\")").json().stringify(),
    content="true",
  )
}

///|
test "join null" {
  inspect(
    @eval.feel_eval("string join([\"a\",null,\"b\"],\",\")").json().stringify(),
    content="\"a,b\"",
  )
}

///|
test "replace" {
  inspect(
    @eval.feel_eval("replace(\"aba\",\"a\",\"x\")").json().stringify(),
    content="\"xbx\"",
  )
}

///|
test "matches" {
  inspect(
    @eval.feel_eval("matches(\"abc\",\"b\")").json().stringify(),
    content="true",
  )
}

///|
test "split" {
  inspect(
    @eval.feel_eval("split(\"a,b\",\",\")").json().stringify(),
    content="[\"a\",\"b\"]",
  )
}

///|
test "reverse" {
  inspect(@eval.feel_eval("reverse([1,2])").json().stringify(), content="[2,1]")
}

///|
test "append" {
  inspect(
    @eval.feel_eval("append([1],2,3)").json().stringify(),
    content="[1,2,3]",
  )
}

///|
test "flatten" {
  inspect(
    @eval.feel_eval("flatten([1,[2,[3]]])").json().stringify(),
    content="[1,2,3]",
  )
}

///|
test "distinct" {
  inspect(
    @eval.feel_eval("distinct values([1,1,2])").json().stringify(),
    content="[1,2]",
  )
}

///|
test "union" {
  inspect(
    @eval.feel_eval("union([1,2],[2,3])").json().stringify(),
    content="[1,2,3]",
  )
}

///|
test "index of" {
  inspect(
    @eval.feel_eval("index of([1,2,1],1)").json().stringify(),
    content="[1,3]",
  )
}

///|
test "list contains" {
  inspect(
    @eval.feel_eval("list contains([1,2],2)").json().stringify(),
    content="true",
  )
}

///|
test "sublist" {
  inspect(
    @eval.feel_eval("sublist([1,2,3],2,1)").json().stringify(),
    content="[2]",
  )
}

///|
test "insert" {
  inspect(
    @eval.feel_eval("insert before([1,3],2,2)").json().stringify(),
    content="[1,2,3]",
  )
}

///|
test "remove" {
  inspect(@eval.feel_eval("remove([1,2],1)").json().stringify(), content="[2]")
}

///|
test "list replace" {
  inspect(
    @eval.feel_eval("list replace([1,2],2,3)").json().stringify(),
    content="[1,3]",
  )
}

///|
test "get value" {
  inspect(
    @eval.feel_eval("get value({a:1},\"a\")").json().stringify(),
    content="1",
  )
}

///|
test "context put" {
  inspect(
    @eval.feel_eval("context put({a:1},\"a\",2)").json().stringify(),
    content="{\"a\":2}",
  )
}

///|
test "context merge" {
  inspect(
    @eval.feel_eval("context merge([{a:1},{a:2}])").json().stringify(),
    content="{\"a\":2}",
  )
}

///|
test "context duplicate" {
  inspect(
    @eval.feel_eval("context([{key:\"a\",value:1},{key:\"a\",value:2}])")
    .json()
    .stringify(),
    content="null",
  )
}

///|
test "weekday" {
  inspect(
    @eval.feel_eval("day of week(@\"2024-02-29\")").json().stringify(),
    content="\"Thursday\"",
  )
}

///|
test "month name" {
  inspect(
    @eval.feel_eval("month of year(@\"2024-02-29\")").json().stringify(),
    content="\"February\"",
  )
}

///|
test "day of year" {
  inspect(
    @eval.feel_eval("day of year(@\"2024-03-01\")").json().stringify(),
    content="61",
  )
}

///|
test "week of year" {
  inspect(
    @eval.feel_eval("week of year(@\"2021-01-01\")").json().stringify(),
    content="53",
  )
}

///|
test "whole months" {
  inspect(
    @eval.feel_eval(
      "years and months duration(@\"2020-01-31\",@\"2021-03-01\")",
    )
    .json()
    .stringify(),
    content="\"P1Y1M\"",
  )
}

///|
test "meets" {
  inspect(
    @eval.feel_eval("meets([1..2],[2..3])").json().stringify(),
    content="true",
  )
}

///|
test "open not meets" {
  inspect(
    @eval.feel_eval("meets([1..2),[2..3])").json().stringify(),
    content="false",
  )
}

///|
test "includes open" {
  inspect(
    @eval.feel_eval("includes((1..3),(1..2))").json().stringify(),
    content="true",
  )
}

///|
test "before" {
  inspect(@eval.feel_eval("before(1,2)").json().stringify(), content="true")
}

///|
test "after" {
  inspect(@eval.feel_eval("after(3,2)").json().stringify(), content="true")
}

///|
test "coincides" {
  inspect(
    @eval.feel_eval("coincides([1..2],[1..2])").json().stringify(),
    content="true",
  )
}

///|
test "range reversed" {
  inspect(
    @eval.feel_eval("range(\"[3..1]\")").json().stringify(),
    content="null",
  )
}

///|
test "range mixed" {
  inspect(
    @eval.feel_eval("range(\"[1..\\\"b\\\"]\")").json().stringify(),
    content="null",
  )
}

///|
test "range open" {
  inspect(
    @eval.feel_eval("range(\"]1..3[\") = (1..3)").json().stringify(),
    content="true",
  )
}

///|
test "sqrt named" {
  inspect(@eval.feel_eval("sqrt(number:4)").json().stringify(), content="2")
}

///|
test "sqrt wrong name" {
  inspect(@eval.feel_eval("sqrt(n:4)").json().stringify(), content="null")
}

///|
test "abs wrong name" {
  inspect(@eval.feel_eval("abs(number:-1)").json().stringify(), content="null")
}

///|
test "date named" {
  inspect(
    @eval.feel_eval("day of week(date:@\"2024-02-29\")").json().stringify(),
    content="\"Thursday\"",
  )
}

///|
test "date wrong name" {
  inspect(
    @eval.feel_eval("day of week(value:@\"2024-02-29\")").json().stringify(),
    content="null",
  )
}

///|
test "duplicate argument" {
  inspect(
    @eval.feel_eval("modulo(1, dividend:2, divisor:3)").json().stringify(),
    content="null",
  )
}

///|
test "nested context put" {
  inspect(
    @eval.feel_eval("context put({a:{b:1}},[\"a\",\"b\"],2)").json().stringify(),
    content="{\"a\":{\"b\":2}}",
  )
}

///|
test "get value named" {
  inspect(
    @eval.feel_eval("get value(m:{a:1},key:\"a\")").json().stringify(),
    content="1",
  )
}

///|
test "get entries named" {
  inspect(
    @eval.feel_eval("get entries(m:{a:1})").json().stringify(),
    content="[{\"key\":\"a\",\"value\":1}]",
  )
}

///|
test "regex dot newline" {
  inspect(
    @eval.feel_eval("matches(\"a\\nb\",\"a.b\")").json().stringify(),
    content="false",
  )
}

///|
test "regex dotall" {
  inspect(
    @eval.feel_eval("matches(\"a\\nb\",\"a.b\",\"s\")").json().stringify(),
    content="true",
  )
}

///|
test "regex whitespace" {
  inspect(
    @eval.feel_eval("matches(\"ab\",\"a b\",\"x\")").json().stringify(),
    content="true",
  )
}

///|
test "regex multiline" {
  inspect(
    @eval.feel_eval("matches(\"a\\nb\",\"^b$\",\"m\")").json().stringify(),
    content="true",
  )
}

///|
test "regex null flags" {
  inspect(
    @eval.feel_eval("matches(\"ab\",\"a\",null)").json().stringify(),
    content="true",
  )
}

///|
test "scaled floor" {
  inspect(@eval.feel_eval("floor(1.234,2)").json().stringify(), content="1.23")
}

///|
test "scaled ceiling" {
  inspect(
    @eval.feel_eval("ceiling(1.234,2)").json().stringify(),
    content="1.24",
  )
}

///|
test "duration negate" {
  inspect(@eval.feel_eval("-@\"P1D\"").json().stringify(), content="\"-P1D\"")
}

///|
test "duration months negate" {
  inspect(@eval.feel_eval("-@\"P1Y\"").json().stringify(), content="\"-P1Y\"")
}

///|
test "is temporal identity" {
  inspect(
    @eval.feel_eval("is(@\"12:00:00Z\",@\"13:00:00+01:00\")").json().stringify(),
    content="false",
  )
}

///|
test "range date constructors" {
  inspect(
    @eval.feel_eval(
      "range(\"[date(\\\"2024-01-01\\\")..date(\\\"2024-01-02\\\")]\") = [@\"2024-01-01\"..@\"2024-01-02\"]",
    )
    .json()
    .stringify(),
    content="true",
  )
}

///|
test "before touching closed intervals" {
  inspect(
    @eval.feel_eval("before([1..2],[2..3])").json().stringify(),
    content="false",
  )
}

///|
test "null is not Any" {
  inspect(
    @eval.feel_eval("null instance of Any").json().stringify(),
    content="false",
  )
}
