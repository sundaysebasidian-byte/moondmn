///|
fn option(
  args : Array[String],
  name : String,
) -> String raise @types.EngineError {
  for i, arg in args {
    if arg == name && i + 1 < args.length() {
      return args[i + 1]
    }
  }
  raise @types.fail("E_CLI_ARGUMENT", "missing " + name)
}

///|
fn run(args : Array[String]) -> Unit raise Error {
  if args.length() < 3 {
    raise @types.fail(
      "E_CLI_USAGE", "moondmn feel <expr> [--context file] | eval <model> --decision name --input file",
    )
  }
  match args[1] {
    "tck" => {
      let report = @tck.run(args[2]).stringify(indent=2)
      if args.contains("--json") {
        @fs.write_string_to_file(option(args, "--json"), report)
      } else {
        println(report)
      }
    }
    "feel" => {
      let context = if args.contains("--context") {
        @fs.read_file_to_string(option(args, "--context"))
      } else {
        "{}"
      }
      println(@lib.feel_eval(args[2], context~))
    }
    "eval" => {
      let model = @lib.parse_model(@fs.read_file_to_string(args[2]))
      println(
        @lib.evaluate_decision(
          model,
          option(args, "--decision"),
          @fs.read_file_to_string(option(args, "--input")),
        ),
      )
    }
    _ => raise @types.fail("E_CLI_USAGE", "unknown command")
  }
}

///|
fn main {
  run(@env.args()) catch {
    @types.Failure(code, line, column, message) => {
      println(
        Json::object(
          Map([
            ("error", Json(code)),
            ("line", Json(line)),
            ("column", Json(column)),
            ("message", Json(message)),
          ]),
        ).stringify(),
      )
      @sys.exit(1)
    }
    e => {
      println(
        Json::object(
          Map([("error", Json("E_IO")), ("message", Json(e.to_string()))]),
        ).stringify(),
      )
      @sys.exit(1)
    }
  }
}
