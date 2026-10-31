///|
fn main {
  let source = "sum([amount, 0.1, 0.2]) * 2"
  let expression = @lib.compile(source, names=["amount"]) catch {
    _ => abort("benchmark failed")
  }
  let input = @types.json_context("{\"amount\":12}") catch {
    _ => abort("benchmark failed")
  }
  let t = @bench.monotonic_clock_start()
  for iteration = 0; iteration < 10000; iteration = iteration + 1 {
    ignore(
      @eval.evaluate(expression, input) catch {
        _ => abort("benchmark failed")
      },
    )
  }
  println(
    "compiled_10000_ms=" + (@bench.monotonic_clock_end(t) / 1000.0).to_string(),
  )
  let t = @bench.monotonic_clock_start()
  for iteration = 0; iteration < 10000; iteration = iteration + 1 {
    ignore(
      @eval.feel_eval(source, ctx=input) catch {
        _ => abort("benchmark failed")
      },
    )
  }
  println(
    "parsed_10000_ms=" + (@bench.monotonic_clock_end(t) / 1000.0).to_string(),
  )
  let xml = StringBuilder()
  xml.write_string(
    "<definitions xmlns='https://www.omg.org/spec/DMN/20230324/MODEL/'><decision id='d' name='d'><decisionTable hitPolicy='FIRST'><input><inputExpression><text>n</text></inputExpression></input><output/>",
  )
  for i = 0; i < 1000; i = i + 1 {
    xml.write_string(
      "<rule><inputEntry><text>" +
      i.to_string() +
      "</text></inputEntry><outputEntry><text>" +
      i.to_string() +
      "</text></outputEntry></rule>",
    )
  }
  xml.write_string("</decisionTable></decision></definitions>")
  let model = @lib.parse_model(xml.to_string()) catch {
    _ => abort("benchmark failed")
  }
  let t = @bench.monotonic_clock_start()
  for iteration = 0; iteration < 10000; iteration = iteration + 1 {
    let result = @lib.evaluate_decision(model, "d", "{\"n\":999}") catch {
      _ => abort("benchmark failed")
    }
    assert_eq(result, "999") catch {
      _ => abort("benchmark failed")
    }
  }
  println(
    "table_1000_rules_10000_ms=" +
    (@bench.monotonic_clock_end(t) / 1000.0).to_string(),
  )
}
