///|
test "missing operand" {
  let failed = try {
    ignore(@parser.compile("1 +"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "missing then" {
  let failed = try {
    ignore(@parser.compile("if true 1 else 2"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "unclosed list" {
  let failed = try {
    ignore(@parser.compile("[1,2"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "unclosed context" {
  let failed = try {
    ignore(@parser.compile("{a:1"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "trailing token" {
  let failed = try {
    ignore(@parser.compile("1 2"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "unclosed call" {
  let failed = try {
    ignore(@parser.compile("f(1"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "bad range" {
  let failed = try {
    ignore(@parser.compile("[1..."))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}
