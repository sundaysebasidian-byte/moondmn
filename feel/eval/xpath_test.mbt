///|
test "Unicode simple folding in regex literals and ranges" {
  inspect(
    @eval.feel_eval("matches(\"K\", \"k\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ς\", \"Σ\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ſ\", \"[A-Z]\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ss\", \"^ß$\", \"i\")").text(),
    content="false",
  )
}

///|
test "XPath subtraction after case expansion" {
  inspect(
    @eval.feel_eval("matches(\"b\", \"[a-z-[aeiou]]\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"a\", \"[a-z-[aeiou]]\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"X\", \"[a-z-[oi]]\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"O\", \"[a-z-[oi]]\", \"i\")").text(),
    content="false",
  )
}

///|
test "XPath captures and case blind backreferences" {
  inspect(
    @eval.feel_eval("matches(\"bB\", \"(b)\\1\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"bB\", \"(b)\\1\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"abab\", \"^(a|ab)\\1$\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"b\", \"^(a)?b\\1$\")").text(),
    content="true",
  )
}

///|
test "comparison range preserves operator" {
  inspect(@eval.feel_eval("(=3) = [3..3]").text(), content="false")
  inspect(@eval.feel_eval("(=3) = (=3)").text(), content="true")
  inspect(@eval.feel_eval("(!=3) = (=3)").text(), content="false")
}

///|
test "XPath nested subtraction and Unicode properties" {
  inspect(
    @eval.feel_eval("matches(\"a\", \"[a-z-[a-z-[aeiou]]]\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"b\", \"[a-z-[a-z-[aeiou]]]\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"x\", \"[A-Z-[OI]]\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"i\", \"[A-Z-[OI]]\", \"i\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"K\", \"[^k]\", \"i\")").text(),
    content="false",
  )
}

///|
test "XPath backreference numbering and validation" {
  inspect(
    @eval.feel_eval("matches(\"abab\", \"^(?:x)?(ab)\\1$\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"abb\", \"^([ab])+\\1$\")").text(),
    content="true",
  )
  inspect(@eval.feel_eval("matches(\"aa\", \"\\1(a)\")").text(), content="null")
  inspect(@eval.feel_eval("matches(\"aa\", \"(a\\1)\")").text(), content="null")
  inspect(
    @eval.feel_eval("matches(\"a\", \"[a-z-[b]\")").text(),
    content="null",
  )
  inspect(@eval.feel_eval("matches(\"a\", \"[z-a]\")").text(), content="null")
}

///|
test "XPath quantifiers anchors and flags" {
  inspect(
    @eval.feel_eval("matches(\"a\", \"a{10001}\")").text(),
    content="null",
  )
  inspect(
    @eval.feel_eval("matches(\"abab\", \"^(ab){2,3}$\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ab\", \"^(ab){2,3}$\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"a\\nb\", \"^a.*b$\", \"ms\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"a\\nb\", \"a.b\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"b\\n\", \"^$\", \"m\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"𐐨\", \"𐐀\", \"i\")").text(),
    content="true",
  )
}

///|
test "comparison range membership and nested equality" {
  inspect(@eval.feel_eval("3 in [(=3)]").text(), content="true")
  inspect(@eval.feel_eval("4 in [(=3)]").text(), content="false")
  inspect(@eval.feel_eval("4 in [(!=3)]").text(), content="true")
  inspect(@eval.feel_eval("[(=3)] = [[3..3]]").text(), content="false")
  inspect(@eval.feel_eval("{x:(=3)} = {x:(=3)}").text(), content="true")
}
