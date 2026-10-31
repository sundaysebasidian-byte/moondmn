///|
fn wrap_r1(body : String) -> String {
  "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='D' name='D'>" +
  body +
  "</decision></definitions>"
}

///|
test "conditional requires all three unique branches before evaluation" {
  let branches = [
    "<if><literalExpression><text>false</text></literalExpression></if>", "<then><literalExpression><text>1</text></literalExpression></then>",
    "<else><literalExpression><text>2</text></literalExpression></else>",
  ]
  for missing = 0; missing < 3; missing = missing + 1 {
    let parts = branches.copy()
    parts[missing] = ""
    let code = try {
      ignore(
        @model.evaluate_decision(
          @model.parse_model(
            wrap_r1("<conditional>" + parts.join("") + "</conditional>"),
          ),
          "D",
          Map([]),
        ),
      )
      "success"
    } catch {
      @types.Failure(code, line, column, _) => {
        assert_true(line >= 1 && column >= 1)
        code
      }
    }
    inspect(code, content="E_DMN_SHAPE")
  }
}

///|
test "truncated and mutated DMN never trap" {
  let seeds = [
    wrap_r1(
      "<conditional><if><literalExpression><text>false</text></literalExpression></if><then><literalExpression><text>1</text></literalExpression></then></conditional>",
    ),
    wrap_r1(
      "<relation><column name='x'/><row><literalExpression><text>1</text></literalExpression></row></relation>",
    ),
    wrap_r1(
      "<decisionTable><input><inputExpression><text>1</text></inputExpression></input><output/><rule><inputEntry><text>-</text></inputEntry><outputEntry><text>1</text></outputEntry></rule></decisionTable>",
    ),
    wrap_r1(
      "<invocation><literalExpression><text>1</text></literalExpression><binding/></invocation>",
    ),
  ]
  let mut state = 773U
  let mut errors = 0
  for source in seeds {
    let chars = source.to_array()
    for attempt = 0; attempt < 300; attempt = attempt + 1 {
      state = state * 1664525U + 1013904223U
      let at = (state % chars.length().reinterpret_as_uint()).reinterpret_as_int()
      let altered = if attempt % 2 == 0 {
        String::from_array(chars[:at].to_owned())
      } else {
        let copy = chars.copy()
        copy[at] = ['<', '>', '/', '"', '&', '0'][attempt % 6]
        String::from_array(copy)
      }
      ignore(
        @model.evaluate_decision(@model.parse_model(altered), "D", Map([])),
      ) catch {
        @types.Failure(code, _, _, _) => {
          assert_true(code.has_prefix("E_"))
          errors = errors + 1
        }
      }
    }
  }
  assert_true(errors > 1000)
}
