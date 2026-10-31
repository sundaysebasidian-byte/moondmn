///|
test "option value" {
  inspect(option(["feel", "x", "--now", "2024"], "--now"), content="2024")
}

///|
test "missing option" {
  let code = try {
    ignore(option([], "--input"))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_CLI_ARGUMENT")
}

///|
test "missing option value" {
  let code = try {
    ignore(option(["--input"], "--input"))
    "success"
  } catch {
    e => @types.error_code(e)
  }
  inspect(code, content="E_CLI_ARGUMENT")
}

///|
test "unknown command" {
  let code = try {
    run(["moondmn", "bad", "x"])
    "success"
  } catch {
    @types.Failure(c, _, _, _) => c
    _ => "other"
  }
  inspect(code, content="E_CLI_USAGE")
}
