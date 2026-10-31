///|
pub(all) enum Expr {
  Literal(@types.Value)
  Name(String)
  Unary(String, Expr)
  Binary(String, Expr, Expr)
  Conditional(Expr, Expr, Expr)
  Sequence(Array[Expr])
  Record(Array[(String, Expr)])
  Call(String, Array[Expr])
  Path(Expr, String)
}

///|
priv struct Parser {
  tokens : Array[@lexer.Token]
  mut pos : Int32
  mut depth : Int32
}

///|
fn Parser::peek(p : Parser) -> String {
  p.tokens[p.pos].text
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
fn Parser::expect(p : Parser, s : String) -> Unit raise @types.EngineError {
  if p.peek() != s {
    let t = p.tokens[p.pos]
    raise @types.Failure(
      "E_PARSE",
      t.line,
      t.column,
      "expected " + s + ", got " + t.text,
    )
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
    _ => 0
  }
}

///|
fn Parser::expr(p : Parser, minimum : Int32) -> Expr raise @types.EngineError {
  p.depth = p.depth + 1
  if p.depth > 128 {
    raise @types.fail("E_LIMIT", "expression nesting limit")
  }
  let mut left = p.atom()
  while precedence(p.peek()) >= minimum && precedence(p.peek()) > 0 {
    let op = p.take().text
    left = Binary(op, left, p.expr(precedence(op) + 1))
  }
  p.depth = p.depth - 1
  left
}

///|
fn Parser::atom(p : Parser) -> Expr raise @types.EngineError {
  let t = p.take()
  let mut result = match t.text {
    "if" => {
      let c = p.expr(1)
      p.expect("then")
      let a = p.expr(1)
      p.expect("else")
      Conditional(c, a, p.expr(1))
    }
    "-" | "+" => Unary(t.text, p.expr(6))
    "(" => {
      let v = p.expr(1)
      p.expect(")")
      v
    }
    "[" => {
      let xs = []
      if p.peek() != "]" {
        xs.push(p.expr(1))
        while p.peek() == "," {
          ignore(p.take())
          xs.push(p.expr(1))
        }
      }
      p.expect("]")
      Sequence(xs)
    }
    "{" => {
      let xs = []
      while p.peek() != "}" {
        let key = p.take()
        let name = if key.kind == "string" {
          match
            (@json.parse(key.text) catch {
              _ => raise @types.fail("E_PARSE", "bad context key")
            }) {
            String(s) => s
            _ => ""
          }
        } else {
          key.text
        }
        p.expect(":")
        xs.push((name, p.expr(1)))
        if p.peek() != "," {
          break
        }
        ignore(p.take())
      }
      p.expect("}")
      Record(xs)
    }
    "true" => Literal(Boolean(true))
    "false" => Literal(Boolean(false))
    "null" => Literal(Null)
    _ =>
      if t.kind == "number" {
        Literal(Number(@types.decimal(t.text)))
      } else if t.kind == "string" {
        match
          (@json.parse(t.text) catch {
            _ =>
              raise @types.Failure(
                "E_PARSE",
                t.line,
                t.column,
                "invalid string escape",
              )
          }) {
          String(s) => Literal(Text(s))
          _ => Literal(Null)
        }
      } else if t.kind == "name" {
        if p.peek() == "(" {
          ignore(p.take())
          let args = []
          if p.peek() != ")" {
            args.push(p.expr(1))
            while p.peek() == "," {
              ignore(p.take())
              args.push(p.expr(1))
            }
          }
          p.expect(")")
          Call(t.text, args)
        } else {
          Name(t.text)
        }
      } else {
        raise @types.Failure(
          "E_PARSE",
          t.line,
          t.column,
          "unexpected token " + t.text,
        )
      }
  }
  while p.peek() == "." {
    ignore(p.take())
    result = Path(result, p.take().text)
  }
  result
}

///|
pub fn compile(
  source : String,
  names~ : Array[String] = [],
) -> Expr raise @types.EngineError {
  let p = Parser::{ tokens: @lexer.lex(source, names), pos: 0, depth: 0, }
  let expr = p.expr(1)
  if p.tokens[p.pos].kind != "eof" {
    let t = p.tokens[p.pos]
    raise @types.Failure(
      "E_UNSUPPORTED_SYNTAX",
      t.line,
      t.column,
      "unsupported or trailing syntax: " + t.text,
    )
  }
  expr
}
