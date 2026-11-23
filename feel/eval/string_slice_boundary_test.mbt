///|
test "substring boundaries use Unicode supplementary characters" {
  let cases = [
    ("substring before(\"😀ab\", \"a\")", "😀"),
    ("substring after(\"😀ab\", \"a\")", "b"),
    ("substring before(\"😀x😀y\", \"😀y\")", "😀x"),
    ("substring after(\"😀x😀yz\", \"😀y\")", "z"),
    ("substring after(\"😀ababa\", \"ab\")", "aba"),
    ("substring before(\"😀ab\", \"\")", ""),
    ("substring after(\"😀ab\", \"\")", "😀ab"),
    ("substring before(\"😀ab\", \"z\")", ""),
    ("substring after(\"😀ab\", \"z\")", ""),
  ]
  for pair in cases {
    assert_eq(@eval.feel_eval(pair.0).text(), pair.1)
  }
}
