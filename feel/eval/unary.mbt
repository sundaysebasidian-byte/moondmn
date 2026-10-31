///|
/// Split only at top-level delimiters, preserving nested expressions and strings.
pub fn split_tests(source : String) -> Array[String] raise @types.EngineError {
  let out = []
  let mut b = StringBuilder()
  let mut depth = 0
  let mut quoted = false
  let mut escape = false
  for ch in source.to_array() {
    if escape {
      b.write_char(ch)
      escape = false
      continue
    }
    if quoted && ch == '\\' {
      b.write_char(ch)
      escape = true
      continue
    }
    if ch == '"' {
      quoted = !quoted
    }
    if !quoted {
      if ch == '(' || ch == '[' || ch == '{' {
        depth = depth + 1
      }
      if ch == ')' || ch == ']' || ch == '}' {
        depth = depth - 1
      }
      if ch == ',' && depth == 0 {
        out.push(b.to_string().trim().to_owned())
        b = StringBuilder()
        continue
      }
    }
    b.write_char(ch)
  }
  if quoted || depth != 0 {
    raise @types.fail("E_UNARY_PARSE", "unbalanced unary test")
  }
  out.push(b.to_string().trim().to_owned())
  out
}

///|
pub fn unary_test(
  source : String,
  input : @types.Value,
  ctx : Map[String, @types.Value],
) -> Bool raise @types.EngineError {
  let source = source.trim().to_owned()
  if source == "-" {
    return true
  }
  let scope = ctx.copy()
  scope["?"] = input
  let tests = split_tests(source)
  if tests.length() > 1 {
    for item in tests {
      if unary_test(item, input, ctx) {
        return true
      }
    }
    return false
  }
  if source.has_prefix("not(") && source.has_suffix(")") {
    let inner = source
      .strip_prefix("not(")
      .unwrap()
      .strip_suffix(")")
      .unwrap()
      .to_owned()
    return !unary_test(inner, input, ctx)
  }
  if source.has_prefix("[") || source.has_prefix("(") {
    let parts = source.split("..").to_array()
    if parts.length() == 2 {
      let left = parts[0].to_array()
      let right = parts[1].to_array()
      if left.length() < 2 || right.length() < 2 {
        raise @types.fail("E_UNARY_PARSE", "invalid range")
      }
      let low = String::from_array(left[1:].to_owned())
      let high = String::from_array(right[:right.length() - 1].to_owned())
      let lo = binary(
        if left[0] == '[' {
          ">="
        } else {
          ">"
        },
        input,
        feel_eval(low, ctx~),
      )
      let hi = binary(
        if right[right.length() - 1] == ']' {
          "<="
        } else {
          "<"
        },
        input,
        feel_eval(high, ctx~),
      )
      return lo == Boolean(true) && hi == Boolean(true)
    }
  }
  for op in ["<=", ">=", "<", ">", "="] {
    if source.has_prefix(op) {
      let other = feel_eval(source.strip_prefix(op).unwrap().to_owned(), ctx~)
      return binary(op, input, other) == Boolean(true)
    }
  }
  if source.contains("?") {
    return feel_eval(source, ctx=scope) == Boolean(true)
  }
  input == feel_eval(source, ctx~)
}
