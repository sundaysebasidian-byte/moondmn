///|
test "Noncontiguous comparison ranges have undefined interval relations" {
  inspect(@eval.feel_eval("overlaps((!=3), [1..2])").text(), content="null")
  inspect(@eval.feel_eval("overlaps([1..2], (!=3))").text(), content="null")
  inspect(@eval.feel_eval("before((!=3), [1..2])").text(), content="null")
  inspect(@eval.feel_eval("before([1..2], (!=3))").text(), content="null")
  inspect(@eval.feel_eval("after((!=3), [1..2])").text(), content="null")
  inspect(@eval.feel_eval("after([1..2], (!=3))").text(), content="null")
  inspect(@eval.feel_eval("meets((!=3), [1..2])").text(), content="null")
  inspect(@eval.feel_eval("meets([1..2], (!=3))").text(), content="null")
  inspect(@eval.feel_eval("met by((!=3), [1..2])").text(), content="null")
  inspect(@eval.feel_eval("met by([1..2], (!=3))").text(), content="null")
  inspect(
    @eval.feel_eval("overlaps before((!=3), [1..2])").text(),
    content="null",
  )
  inspect(
    @eval.feel_eval("overlaps before([1..2], (!=3))").text(),
    content="null",
  )
  inspect(
    @eval.feel_eval("overlaps after((!=3), [1..2])").text(),
    content="null",
  )
  inspect(
    @eval.feel_eval("overlaps after([1..2], (!=3))").text(),
    content="null",
  )
  inspect(@eval.feel_eval("includes((!=3), [1..2])").text(), content="null")
  inspect(@eval.feel_eval("includes([1..2], (!=3))").text(), content="null")
  inspect(@eval.feel_eval("during((!=3), [1..2])").text(), content="null")
  inspect(@eval.feel_eval("during([1..2], (!=3))").text(), content="null")
  inspect(@eval.feel_eval("starts((!=3), [1..2])").text(), content="null")
  inspect(@eval.feel_eval("starts([1..2], (!=3))").text(), content="null")
  inspect(@eval.feel_eval("started by((!=3), [1..2])").text(), content="null")
  inspect(@eval.feel_eval("started by([1..2], (!=3))").text(), content="null")
  inspect(@eval.feel_eval("finishes((!=3), [1..2])").text(), content="null")
  inspect(@eval.feel_eval("finishes([1..2], (!=3))").text(), content="null")
  inspect(@eval.feel_eval("finished by((!=3), [1..2])").text(), content="null")
  inspect(@eval.feel_eval("finished by([1..2], (!=3))").text(), content="null")
  inspect(@eval.feel_eval("coincides((!=3), [1..2])").text(), content="null")
  inspect(@eval.feel_eval("coincides([1..2], (!=3))").text(), content="null")
  inspect(@eval.feel_eval("1 in (!=3)").text(), content="true")
  inspect(@eval.feel_eval("(=3) = [3..3]").text(), content="false")
  inspect(@eval.feel_eval("coincides((=3), [3..3])").text(), content="true")
  inspect(@eval.feel_eval("3 in (=3)").text(), content="true")
  inspect(@eval.feel_eval("4 in (=3)").text(), content="false")
}

///|
test "Range text permits missing open endpoints" {
  inspect(@eval.feel_eval("range(\"(..2)\") = (<2)").text(), content="true")
  inspect(@eval.feel_eval("range(\"[2..)\") = (>=2)").text(), content="true")
  inspect(
    @eval.feel_eval("range(\"[18..21)\") = [18..21)").text(),
    content="true",
  )
  inspect(@eval.feel_eval("range(\"[..2]\")").text(), content="null")
  inspect(@eval.feel_eval("range(\"[1..]\")").text(), content="null")
  inspect(@eval.feel_eval("range(\"[..]\")").text(), content="null")
  inspect(@eval.feel_eval("range(\"\")").text(), content="null")
  inspect(@eval.feel_eval("range(\"(=3)\")").text(), content="null")
  inspect(@eval.feel_eval("range(\"(<=3)\")").text(), content="null")
}
