///|
/// A positional or named FEEL call argument.
pub(all) struct Arg {
  name : String?
  value : Expr
}

///|
/// Compiled FEEL expression tree; treat as immutable after compilation.
pub(all) enum Expr {
  Lit(@types.Value)
  Name(String)
  Unary(String, Expr)
  Binary(String, Expr, Expr)
  IfThenElse(Expr, Expr, Expr)
  ListLit(Array[Expr])
  ContextLit(Array[(String, Expr)])
  RangeLit(Expr?, Bool, Expr?, Bool)
  Seq(Expr, Expr)
  Call(Expr, Array[Arg])
  Path(Expr, String)
  Filter(Expr, Expr)
  For(Array[(String, Expr)], Expr)
  SomeIn(Array[(String, Expr)], Expr)
  EveryIn(Array[(String, Expr)], Expr)
  FunctionDef(Array[String], Expr)
  InstanceOf(Expr, String)
  Between(Expr, Expr, Expr)
  In(Expr, Test)
}

///|
/// A unary test as used by decision table input entries and the `in` operator.
pub(all) enum Test {
  AnyTest
  NotTest(Test)
  CompareTest(String, Expr)
  RangeTest(Expr?, Bool, Expr?, Bool)
  ExprTest(Expr)
  AnyOfTest(Array[Test])
}

///|
priv struct Parser {
  tokens : Array[@lexer.Token]
  mut pos : Int32
  mut depth : Int32
  mut in_range : Bool
}

///|
fn Parser::peek(p : Parser) -> @lexer.Token {
  p.tokens[p.pos]
}

///|
fn Parser::peek_at(p : Parser, offset : Int32) -> @lexer.Token {
  let at = p.pos + offset
  if at >= p.tokens.length() {
    p.tokens[p.tokens.length() - 1]
  } else {
    p.tokens[at]
  }
}

///|
fn Parser::take(p : Parser) -> @lexer.Token {
  let t = p.tokens[p.pos]
  if t.kind != "eof" {
    p.pos = p.pos + 1
  }
  t
}

///|
fn Parser::at(p : Parser, text : String) -> Bool {
  p.peek().kind != "string" && p.peek().text == text
}

///|
fn Parser::error(
  p : Parser,
  code : String,
  message : String,
) -> Unit raise @types.EngineError {
  let t = p.peek()
  raise @types.Failure(code, t.line, t.column, message)
}

///|
fn Parser::expect(p : Parser, text : String) -> Unit raise @types.EngineError {
  if !p.at(text) {
    p.error("E_PARSE", "expected " + text + ", got " + p.peek().text)
  }
  ignore(p.take())
}

///|
fn precedence(op : String) -> Int32 {
  match op {
    "or" => 1
    "and" => 2
    "=" | "!=" | "<>" | "<" | ">" | "<=" | ">=" => 3
    "+" | "-" => 4
    "*" | "/" => 5
    "**" => 6
    _ => 0
  }
}

///|
fn has_ym_part(text : String) -> Bool {
  let chars = text.to_array()
  let mut i = 0
  if chars.length() > 0 && (chars[0] == '-' || chars[0] == '+') {
    i = 1
  }
  while i < chars.length() {
    if chars[i] == 'T' {
      return false
    }
    if chars[i] == 'Y' || chars[i] == 'M' {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn temporal_value(
  text : String,
  line : Int32,
  column : Int32,
) -> @types.Value raise @types.EngineError {
  let s = text.trim().to_owned()
  let chars = s.to_array()
  if chars.length() == 0 {
    raise @types.Failure("E_TEMPORAL", line, column, "empty temporal literal")
  }
  let mut at = 0
  if chars[0] == '-' || chars[0] == '+' {
    at = 1
  }
  if at < chars.length() && chars[at] == 'P' {
    let (days, months) = @types.parse_duration(s) catch {
      e =>
        raise @types.Failure(
          @types.error_code(e),
          line,
          column,
          @types.error_message(e),
        )
    }
    return if has_ym_part(s) {
      @types.YearsMonths(months)
    } else {
      @types.DaysSeconds(days)
    }
  }
  let mut has_dash = false
  let mut has_colon = false
  let mut has_t = false
  for ch in chars {
    if ch == '-' {
      has_dash = true
    }
    if ch == ':' {
      has_colon = true
    }
    if ch == 'T' {
      has_t = true
    }
  }
  if has_dash && has_t {
    return @types.DateTime(
      @types.parse_datetime(s) catch {
        e =>
          raise @types.Failure(
            @types.error_code(e),
            line,
            column,
            @types.error_message(e),
          )
      },
    )
  }
  if has_colon {
    return @types.Time(
      @types.parse_time(s) catch {
        e =>
          raise @types.Failure(
            @types.error_code(e),
            line,
            column,
            @types.error_message(e),
          )
      },
    )
  }
  if has_dash {
    return @types.Date(
      @types.parse_date(s) catch {
        e =>
          raise @types.Failure(
            @types.error_code(e),
            line,
            column,
            @types.error_message(e),
          )
      },
    )
  }
  raise @types.Failure("E_TEMPORAL", line, column, "unknown temporal literal")
}

///|
fn Parser::expr(p : Parser, minimum : Int32) -> Expr raise @types.EngineError {
  p.depth = p.depth + 1
  if p.depth > 256 {
    p.error("E_LIMIT", "expression nesting limit")
  }
  let mut left = p.unary()
  while true {
    let t = p.peek()
    if t.text == "between" && minimum <= 3 {
      ignore(p.take())
      let low = p.expr(4)
      p.expect("and")
      let high = p.expr(4)
      left = Between(left, low, high)
      continue
    }
    if t.text == "in" && minimum <= 3 {
      ignore(p.take())
      left = In(left, p.in_operand())
      continue
    }
    if t.text == "instance" && p.peek_at(1).text == "of" && minimum <= 3 {
      ignore(p.take())
      ignore(p.take())
      left = InstanceOf(left, p.type_name())
      continue
    }
    let prec = precedence(t.text)
    if prec == 0 || prec < minimum {
      break
    }
    let op = p.take().text
    let right = p.expr(if op == "**" { 6 } else { prec + 1 })
    left = Binary(op, left, right)
  }
  p.depth = p.depth - 1
  left
}

///|
fn join_fields(fields : Array[String]) -> String {
  let out = StringBuilder()
  for i, field in fields {
    if i > 0 {
      out.write_string(", ")
    }
    out.write_string(field)
  }
  out.to_string()
}

///|
fn Parser::type_name(p : Parser) -> String raise @types.EngineError {
  let t = p.take()
  if t.kind != "name" {
    raise @types.Failure("E_PARSE", t.line, t.column, "expected a type name")
  }
  let mut name = t.text
  if p.at("<") {
    ignore(p.take())
    if name.to_lower() == "context" {
      let fields : Array[String] = []
      while !p.at(">") && p.peek().kind != "eof" {
        let field = p.take()
        p.expect(":")
        let ty = p.type_name()
        fields.push(field.text + ": " + ty)
        if p.at(",") {
          ignore(p.take())
        }
      }
      p.expect(">")
      name = name + "<" + join_fields(fields) + ">"
    } else {
      let inner = p.type_name()
      p.expect(">")
      name = name + "<" + inner + ">"
    }
  } else if p.at("<>") {
    ignore(p.take())
    name = name + "<>"
  }
  if p.at("-") && p.peek_at(1).text == ">" {
    ignore(p.take())
    ignore(p.take())
    name = name + " -> " + p.type_name()
  }
  if p.at("and") {
    let n1 = p.peek_at(1)
    let n2 = p.peek_at(2)
    if n1.text == "time" && n2.text == "duration" {
      ignore(p.take())
      ignore(p.take())
      ignore(p.take())
      name = name + " and time duration"
    } else if n1.text == "months" && n2.text == "duration" {
      ignore(p.take())
      ignore(p.take())
      ignore(p.take())
      name = name + " and months duration"
    } else {
      ignore(p.take())
      name = name + " and " + p.take().text
    }
  }
  name
}

///|
fn Parser::unary(p : Parser) -> Expr raise @types.EngineError {
  let t = p.peek()
  if t.text == "-" || t.text == "+" {
    ignore(p.take())
    return Unary(t.text, p.unary())
  }
  if t.text == "not" && p.peek_at(1).text != "(" && p.peek_at(1).kind != "eof" {
    ignore(p.take())
    return Unary("not", p.unary())
  }
  p.postfix()
}

///|
fn Parser::postfix(p : Parser) -> Expr raise @types.EngineError {
  let mut value = p.atom()
  while true {
    let t = p.peek()
    if t.text == "." {
      ignore(p.take())
      let part = p.take()
      if part.kind != "name" && part.kind != "number" && part.kind != "string" {
        raise @types.Failure(
          "E_PARSE",
          part.line,
          part.column,
          "expected a property name",
        )
      }
      value = Path(value, part.text)
    } else if t.text == "[" && !p.in_range {
      ignore(p.take())
      let filter = p.expr(1)
      p.expect("]")
      value = Filter(value, filter)
    } else if t.text == "(" {
      value = p.call(value)
    } else {
      break
    }
  }
  value
}

///|
fn Parser::call(p : Parser, callee : Expr) -> Expr raise @types.EngineError {
  p.expect("(")
  let args = []
  if !p.at(")") {
    while true {
      let mut name : String? = None
      if p.peek().kind == "name" && p.peek_at(1).text == ":" {
        name = Some(p.take().text)
        ignore(p.take())
      }
      args.push({ name, value: p.expr(1), })
      if p.at(",") {
        ignore(p.take())
        continue
      }
      break
    }
  }
  p.expect(")")
  Call(callee, args)
}

///|
fn Parser::atom(p : Parser) -> Expr raise @types.EngineError {
  let t = p.take()
  if t.kind == "string" {
    return Lit(Text(t.text))
  }
  match t.text {
    "if" => {
      let condition = p.expr(1)
      p.expect("then")
      let then = p.expr(1)
      p.expect("else")
      IfThenElse(condition, then, p.expr(1))
    }
    "for" => For(p.bindings(), p.body("return"))
    "some" => SomeIn(p.bindings(), p.body("satisfies"))
    "every" => EveryIn(p.bindings(), p.body("satisfies"))
    "function" => FunctionDef(p.params(), p.expr(1))
    "(" => p.paren_atom()
    "[" => p.bracket_atom()
    "]" => p.close_bracket_atom()
    "{" => p.context_atom()
    "true" => Lit(Boolean(true))
    "false" => Lit(Boolean(false))
    "null" => Lit(Null)
    _ =>
      if t.kind == "number" {
        Lit(
          Number(
            @types.decimal(t.text) catch {
              e =>
                raise @types.Failure(
                  @types.error_code(e),
                  t.line,
                  t.column,
                  @types.error_message(e),
                )
            },
          ),
        )
      } else if t.kind == "string" {
        Lit(Text(t.text))
      } else if t.kind == "temporal" {
        Lit(temporal_value(t.text, t.line, t.column))
      } else if t.kind == "name" {
        Name(t.text)
      } else {
        raise @types.Failure(
          "E_PARSE",
          t.line,
          t.column,
          "unexpected token " + t.text,
        )
      }
  }
}

///|
fn Parser::bindings(
  p : Parser,
) -> Array[(String, Expr)] raise @types.EngineError {
  let out = []
  while true {
    let name = p.take()
    if name.kind != "name" {
      raise @types.Failure(
        "E_PARSE",
        name.line,
        name.column,
        "expected an iteration variable",
      )
    }
    p.expect("in")
    let low = p.expr(1)
    let source = if p.at("..") {
      ignore(p.take())
      Seq(low, p.expr(1))
    } else {
      low
    }
    out.push((name.text, source))
    if p.at(",") {
      ignore(p.take())
      continue
    }
    break
  }
  out
}

///|
fn Parser::body(p : Parser, keyword : String) -> Expr raise @types.EngineError {
  p.expect(keyword)
  p.expr(1)
}

///|
fn Parser::params(p : Parser) -> Array[String] raise @types.EngineError {
  p.expect("(")
  let out = []
  if !p.at(")") {
    while true {
      let name = p.take()
      if name.kind != "name" {
        raise @types.Failure(
          "E_PARSE",
          name.line,
          name.column,
          "expected a parameter name",
        )
      }
      if p.at(":") {
        ignore(p.take())
        while !p.at(",") && !p.at(")") && p.peek().kind != "eof" {
          ignore(p.take())
        }
      }
      out.push(name.text)
      if p.at(",") {
        ignore(p.take())
        continue
      }
      break
    }
  }
  p.expect(")")
  out
}

///|
fn Parser::range_end(p : Parser) -> Expr? raise @types.EngineError {
  if p.at(")") || p.at("]") || p.at("[") {
    return None
  }
  p.in_range = true
  let end = p.expr(1)
  p.in_range = false
  Some(end)
}

///|
fn Parser::range_close(p : Parser) -> @lexer.Token raise @types.EngineError {
  let close = p.take()
  if close.text != ")" && close.text != "]" && close.text != "[" {
    raise @types.Failure(
      "E_PARSE",
      close.line,
      close.column,
      "expected a range delimiter, got " + close.text,
    )
  }
  p.in_range = false
  close
}

///|
fn Parser::paren_atom(p : Parser) -> Expr raise @types.EngineError {
  if p.at("..") {
    ignore(p.take())
    let end = p.range_end()
    let close = p.range_close()
    return RangeLit(None, false, end, close.text == "]")
  }
  let op = p.peek().text
  if op == "<" ||
    op == "<=" ||
    op == ">" ||
    op == ">=" ||
    op == "=" ||
    op == "!=" ||
    op == "<>" {
    ignore(p.take())
    let bound = p.expr(4)
    p.expect(")")
    return match op {
      "<" => RangeLit(None, false, Some(bound), false)
      "<=" => RangeLit(None, false, Some(bound), true)
      ">" => RangeLit(Some(bound), false, None, false)
      ">=" => RangeLit(Some(bound), true, None, false)
      "=" => RangeLit(Some(bound), true, Some(bound), true)
      _ => RangeLit(Some(bound), false, Some(bound), false)
    }
  }
  let first = p.expr(1)
  if p.at("..") {
    ignore(p.take())
    let end = p.range_end()
    let close = p.range_close()
    return RangeLit(Some(first), false, end, close.text == "]")
  }
  p.expect(")")
  first
}

///|
fn Parser::bracket_atom(p : Parser) -> Expr raise @types.EngineError {
  if p.at("]") {
    ignore(p.take())
    return ListLit([])
  }
  if p.at("..") {
    ignore(p.take())
    let end = p.range_end()
    let close = p.range_close()
    return RangeLit(None, true, end, close.text == "]")
  }
  let first = p.expr(1)
  if p.at("..") {
    ignore(p.take())
    let end = p.range_end()
    let close = p.range_close()
    return RangeLit(Some(first), true, end, close.text == "]")
  }
  let items = [first]
  while p.at(",") {
    ignore(p.take())
    items.push(p.expr(1))
  }
  p.expect("]")
  ListLit(items)
}

///|
/// A range that opens with `]`, for example `]1..10]` or `]1..10[`.
fn Parser::close_bracket_atom(p : Parser) -> Expr raise @types.EngineError {
  if p.at("..") {
    ignore(p.take())
    let end = p.range_end()
    let close = p.range_close()
    return RangeLit(None, false, end, close.text == "]")
  }
  let first = p.expr(1)
  p.expect("..")
  let end = p.range_end()
  let close = p.range_close()
  RangeLit(Some(first), false, end, close.text == "]")
}

///|
fn Parser::context_atom(p : Parser) -> Expr raise @types.EngineError {
  let entries = []
  if !p.at("}") {
    while true {
      let key = p.take()
      if key.kind != "name" && key.kind != "string" {
        raise @types.Failure(
          "E_PARSE",
          key.line,
          key.column,
          "expected a context key",
        )
      }
      p.expect(":")
      entries.push((key.text, p.expr(1)))
      if p.at(",") {
        ignore(p.take())
        continue
      }
      break
    }
  }
  p.expect("}")
  ContextLit(entries)
}

///|
fn Parser::range_ahead(p : Parser) -> Bool {
  let mut depth = 0
  let mut i = p.pos
  while i < p.tokens.length() {
    let text = p.tokens[i].text
    if text == "(" || text == "[" || text == "{" {
      depth = depth + 1
    } else if text == ")" || text == "]" || text == "}" {
      depth = depth - 1
      if depth <= 0 {
        return false
      }
    } else if text == ".." && depth == 1 {
      return true
    } else if text == "," && depth == 1 {
      return false
    } else if p.tokens[i].kind == "eof" {
      return false
    }
    i = i + 1
  }
  false
}

///|
fn Parser::in_operand(p : Parser) -> Test raise @types.EngineError {
  if p.at("(") {
    if p.range_ahead() {
      ignore(p.take())
      let start = if p.at("..") { None } else { Some(p.expr(4)) }
      p.expect("..")
      let end = if p.at(")") || p.at("]") { None } else { Some(p.expr(4)) }
      let close = p.take()
      if close.text != ")" && close.text != "]" {
        raise @types.Failure(
          "E_PARSE",
          close.line,
          close.column,
          "expected ) or ]",
        )
      }
      return RangeTest(start, false, end, close.text == "]")
    }
    ignore(p.take())
    let result = p.test_list()
    p.expect(")")
    return result
  }
  p.single_test()
}

///|
fn Parser::test_list(p : Parser) -> Test raise @types.EngineError {
  let tests = [p.single_test()]
  while p.at(",") {
    ignore(p.take())
    tests.push(p.single_test())
  }
  if tests.length() == 1 {
    tests[0]
  } else {
    AnyOfTest(tests)
  }
}

///|
fn expr_test(e : Expr) -> Test {
  match e {
    RangeLit(start, start_included, end, end_included) =>
      RangeTest(start, start_included, end, end_included)
    ListLit(xs) => AnyOfTest(xs.map(x => ExprTest(x)))
    _ => ExprTest(e)
  }
}

///|
fn Parser::single_test(p : Parser) -> Test raise @types.EngineError {
  let t = p.peek()
  let after = p.peek_at(1)
  if t.text == "-" &&
    (after.text == "," || after.text == ")" || after.kind == "eof") {
    ignore(p.take())
    return AnyTest
  }
  if t.text == "not" && after.text == "(" {
    ignore(p.take())
    ignore(p.take())
    let inner = p.test_list()
    p.expect(")")
    return NotTest(inner)
  }
  if ["<", "<=", ">", ">=", "=", "!=", "<>"].contains(t.text) {
    ignore(p.take())
    return CompareTest(t.text, p.expr(4))
  }
  expr_test(p.expr(1))
}

///|
/// Compile a complete FEEL expression using the supplied scoped names.
pub fn compile(
  source : String,
  names~ : Array[String] = [],
) -> Expr raise @types.EngineError {
  let p = Parser::{
    tokens: @lexer.lex(source, names),
    pos: 0,
    depth: 0,
    in_range: false,
  }
  let value = p.expr(1)
  if p.peek().kind != "eof" {
    let t = p.peek()
    raise @types.Failure(
      "E_UNSUPPORTED_SYNTAX",
      t.line,
      t.column,
      "unsupported or trailing syntax: " + t.text,
    )
  }
  value
}

///|
/// Compile a decision table input entry or an `in` operand.
pub fn compile_test(
  source : String,
  names~ : Array[String] = [],
) -> Test raise @types.EngineError {
  let text = source.trim().to_owned()
  if text == "" || text == "-" {
    return AnyTest
  }
  let p = Parser::{
    tokens: @lexer.lex(text, names),
    pos: 0,
    depth: 0,
    in_range: false,
  }
  let result = p.test_list()
  if p.peek().kind != "eof" {
    let t = p.peek()
    raise @types.Failure(
      "E_UNSUPPORTED_SYNTAX",
      t.line,
      t.column,
      "unsupported or trailing syntax: " + t.text,
    )
  }
  result
}
