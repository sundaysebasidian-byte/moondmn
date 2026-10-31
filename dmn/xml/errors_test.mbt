///|
test "empty" {
  let failed = try {
    ignore(@xml.parse(""))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "mismatch" {
  let failed = try {
    ignore(@xml.parse("<a></b>"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "unclosed" {
  let failed = try {
    ignore(@xml.parse("<a>"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "DTD" {
  let failed = try {
    ignore(@xml.parse("<!DOCTYPE a><a/>"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "entity" {
  let failed = try {
    ignore(@xml.parse("<a>&missing;</a>"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "duplicate attribute" {
  let failed = try {
    ignore(@xml.parse("<a x=\"1\" x=\"2\"/>"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}

///|
test "unbound prefix" {
  let failed = try {
    ignore(@xml.parse("<x:a/>"))
    false
  } catch {
    _ => true
  }
  inspect(failed, content="true")
}
