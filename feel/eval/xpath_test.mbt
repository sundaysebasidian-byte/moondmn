///|
test "Unicode case variants in regex literals and ranges" {
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

///|
test "XPath direct upper and lower case variants" {
  inspect(
    @eval.feel_eval("matches(\"ı\", \"I\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ı\", \"i\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ı\", \"[A-Z]\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ı\", \"[^I]\", \"i\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"ı\", \"[A-Z-[O]]\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ϑ\", \"ϴ\", \"i\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"ϴ\", \"ϑ\", \"i\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"𐐨\", \"𐐀\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"K\", \"[A-Z-[O]]\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ẞ\", \"ß\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ß\", \"s\", \"i\")").text(),
    content="false",
  )
}

///|
test "XPath replacement and split share character sets and captures" {
  inspect(
    @eval.feel_eval("replace(\"banana\", \"[a-z-[aeiou]]\", \"X\")").text(),
    content="XaXaXa",
  )
  inspect(
    @eval.feel_eval("replace(\"Kate\", \"k\", \"X\", \"i\")").text(),
    content="Xate",
  )
  inspect(
    @eval.feel_eval("replace(\"abc\", \"b\", \"X\")").text(),
    content="aXc",
  )
  inspect(
    @eval.feel_eval("split(\"aXbXc\", \"X\")").json().stringify(),
    content="[\"a\",\"b\",\"c\"]",
  )
  inspect(
    @eval.feel_eval("split(\"a-b-c\", \"-\")").json().stringify(),
    content="[\"a\",\"b\",\"c\"]",
  )
  inspect(
    @eval.feel_eval("split(\"aa\", \"(a)\\1\")").json().stringify(),
    content="[\"\",\"\"]",
  )
  inspect(
    @eval.feel_eval("replace(\"aa\", \"(a)\\1\", \"$1X\")").text(),
    content="aX",
  )
  inspect(
    @eval.feel_eval("replace(\"abcd\", \"(ab)|(a)\", \"[1=$1][2=$2]\")").text(),
    content="[1=ab][2=]cd",
  )
  inspect(
    @eval.feel_eval("replace(\"a\", \"(a)\", \"$12:$0:$9\")").text(),
    content="a2:a:",
  )
  inspect(
    @eval.feel_eval("replace(\"a\", \"a\", \"\\\\$\\\\\\\\\")").text(),
    content="$\\",
  )
  inspect(
    @eval.feel_eval("replace(\"aaa\", \"a+?\", \"X\")").text(),
    content="XXX",
  )
  inspect(
    @eval.feel_eval("replace(\"aaa\", \"a+\", \"X\")").text(),
    content="X",
  )
  inspect(
    @eval.feel_eval("replace(\"abc\", \"a*\", \"X\")").text(),
    content="null",
  )
  inspect(
    @eval.feel_eval("split(\"abc\", \"a*\")").json().stringify(),
    content="null",
  )
  inspect(
    @eval.feel_eval("replace(\"abc\", \"z\", \"$\")").text(),
    content="null",
  )
  inspect(
    @eval.feel_eval("replace(\"abc\", \"z\", \"\\q\")").text(),
    content="null",
  )
  inspect(
    @eval.feel_eval("split(\"abc\", \"\")").json().stringify(),
    content="[\"a\",\"b\",\"c\"]",
  )
}

///|
test "Nested nullable repetition terminates with a boolean result" {
  inspect(
    @eval.feel_eval("matches(\"b\", \"(a*)*\\1b\")").text(),
    content="true",
  )
  for n in [16, 32, 100, 1000] {
    let input = "a".repeat(n)
    inspect(
      @eval.feel_eval("matches(\"" + input + "\", \"(a*)*b\")").text(),
      content="false",
    )
    inspect(
      @eval.feel_eval("matches(\"" + input + "b\", \"(a*)*b\")").text(),
      content="true",
    )
  }
}

///|
test "XPath variants compare complete Unicode case mappings" {
  inspect(
    @eval.feel_eval("matches(\"ﬅ\", \"ﬆ\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ﬅ\", \"[ﬆ]\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ﬅ\", \"[^ﬆ]\", \"i\")").text(),
    content="false",
  )
  inspect(@eval.feel_eval("matches(\"ﬅ\", \"ﬆ\")").text(), content="false")
  inspect(
    @eval.feel_eval("matches(\"ﬆ\", \"ﬅ\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ﬆ\", \"[ﬅ]\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ﬆ\", \"[^ﬅ]\", \"i\")").text(),
    content="false",
  )
  inspect(@eval.feel_eval("matches(\"ﬆ\", \"ﬅ\")").text(), content="false")
  inspect(
    @eval.feel_eval("matches(\"ΐ\", \"ΐ\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ΐ\", \"[ΐ]\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ΐ\", \"[^ΐ]\", \"i\")").text(),
    content="false",
  )
  inspect(@eval.feel_eval("matches(\"ΐ\", \"ΐ\")").text(), content="false")
  inspect(
    @eval.feel_eval("matches(\"ΐ\", \"ΐ\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ΐ\", \"[ΐ]\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ΐ\", \"[^ΐ]\", \"i\")").text(),
    content="false",
  )
  inspect(@eval.feel_eval("matches(\"ΐ\", \"ΐ\")").text(), content="false")
  inspect(
    @eval.feel_eval("matches(\"ΰ\", \"ΰ\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ΰ\", \"[ΰ]\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ΰ\", \"[^ΰ]\", \"i\")").text(),
    content="false",
  )
  inspect(@eval.feel_eval("matches(\"ΰ\", \"ΰ\")").text(), content="false")
  inspect(
    @eval.feel_eval("matches(\"ΰ\", \"ΰ\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ΰ\", \"[ΰ]\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ΰ\", \"[^ΰ]\", \"i\")").text(),
    content="false",
  )
  inspect(@eval.feel_eval("matches(\"ΰ\", \"ΰ\")").text(), content="false")
  inspect(
    @eval.feel_eval("matches(\"ST\", \"ﬅ\", \"i\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"ss\", \"ß\", \"i\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"ϑ\", \"θ\", \"i\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"θ\", \"ϴ\", \"i\")").text(),
    content="true",
  )
}

///|
test "XPath quoted patterns and literal replacements" {
  inspect(
    @eval.feel_eval("matches(\"abcd\", \".*\", \"q\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"Mr. B. Obama\", \"B. OBAMA\", \"iq\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("replace(\"a/b/c\", \"/\", \"$\", \"q\")").text(),
    content="a$b$c",
  )
  inspect(
    @eval.feel_eval(
      "matches(\"a.*[b](c){2}|^$?+\\\\\", \"a.*[b](c){2}|^$?+\\\\\", \"q\")",
    ).text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"a b\", \"a b\", \"qmxs\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ab\", \"a b\", \"qmxs\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"a\\nb\", \"a.b\", \"qs\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"a\\nb\", \"^b\", \"qm\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"a b\", \"A B\", \"qixms\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("replace(\"a/b/c\", \"/\", \"$1\\\\q\", \"q\")").text(),
    content="a$1\\qb$1\\qc",
  )
  inspect(
    @eval.feel_eval("replace(\"abc\", \"z\", \"$\", \"q\")").text(),
    content="abc",
  )
  inspect(
    @eval.feel_eval("replace(\"abc\", \"\", \"$\", \"q\")").text(),
    content="null",
  )
  inspect(
    @eval.feel_eval("matches(\"abc\", \"\", \"q\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"abc\", \"a\", \"qz\")").text(),
    content="null",
  )
  inspect(
    @eval.feel_eval("matches(\"ﬅ\", \"ﬆ\", \"qi\")").text(),
    content="true",
  )
}

///|
test "XPath free spacing removes XML whitespace before escape parsing" {
  inspect(
    @eval.feel_eval("matches(\"hello world\", \"hello\\\\ world\", \"x\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"hello\\tworld\", \"hello\\\\ sworld\", \"x\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"a x\", \"a\\\\ .\", \"x\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"a.\", \"a\\\\ .\", \"x\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"a \", \"a\\\\ \", \"x\")").text(),
    content="null",
  )
  inspect(
    @eval.feel_eval(
      "replace(\"hello\\tworld\", \"hello\\\\ sworld\", \"X\", \"ix\")",
    ).text(),
    content="X",
  )
  inspect(
    @eval.feel_eval("matches(\"ab\", \"a b\", \"x\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"a b\", \"a[ ]b\", \"x\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"ab\", \"a[ ]b\", \"x\")").text(),
    content="false",
  )
  inspect(
    @eval.feel_eval("matches(\"AB\", \"a b\", \"ix\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"a\\nb\", \"a . b\", \"sx\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"a\\nb\", \"^ b\", \"mx\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"hello world\", \"hello\\\\ sworld\", \"x\")").text(),
    content="true",
  )
  inspect(
    @eval.feel_eval("matches(\"hello world\", \"hello world\", \"x\")").text(),
    content="false",
  )
}
