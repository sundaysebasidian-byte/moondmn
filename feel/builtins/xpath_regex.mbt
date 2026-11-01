///|
priv enum XPathSet {
  Span(Int32, Int32)
  Property(@string.Regex)
  Union(Array[XPathSet])
  Negate(XPathSet)
  Subtract(XPathSet, XPathSet)
}

///|
priv enum XPathRE {
  Character(XPathSet)
  Start
  End
  Sequence(Array[XPathRE])
  Choice(Array[XPathRE])
  Capture(Int32, XPathRE)
  Reference(Int32)
  Repeat(XPathRE, Int32, Int32?)
}

///|
priv struct XPathParser {
  chars : Array[Char]
  mut pos : Int32
  mut groups : Int32
  mut depth : Int32
  closed : Map[Int32, Bool]
}

///|
fn XPathParser::peek(p : XPathParser) -> Char {
  if p.pos < p.chars.length() {
    p.chars[p.pos]
  } else {
    '\u0000'
  }
}

///|
fn XPathParser::take(p : XPathParser) -> Char raise @types.EngineError {
  if p.pos >= p.chars.length() {
    raise err("E_REGEX", "unexpected end of pattern")
  }
  let c = p.chars[p.pos]
  p.pos += 1
  c
}

///|
fn XPathParser::expect(
  p : XPathParser,
  c : Char,
) -> Unit raise @types.EngineError {
  if p.take() != c {
    raise err("E_REGEX", "invalid regular expression delimiter")
  }
}

///|
fn xpath_literal(c : Char) -> XPathSet {
  Span(c.to_int(), c.to_int())
}

///|
fn XPathParser::escape(p : XPathParser) -> XPathSet raise @types.EngineError {
  let c = p.take()
  match c {
    'n' => xpath_literal('\n')
    'r' => xpath_literal('\r')
    't' => xpath_literal('\t')
    's' => Union([' ', '\t', '\n', '\r'].map(xpath_literal))
    'S' => Negate(Union([' ', '\t', '\n', '\r'].map(xpath_literal)))
    'd' | 'D' | 'w' | 'W' | 'p' | 'P' => {
      let b = StringBuilder()
      b.write_char('\\')
      b.write_char(c)
      if c == 'p' || c == 'P' {
        p.expect('{')
        b.write_char('{')
        while p.peek() != '}' {
          b.write_char(p.take())
        }
        b.write_char(p.take())
      }
      let pattern = b.to_string()
      Property(compile_regex(pattern, ""))
    }
    '\\'
    | '|'
    | '.'
    | '-'
    | '^'
    | '$'
    | '?'
    | '*'
    | '+'
    | '{'
    | '}'
    | '('
    | ')'
    | '['
    | ']' => xpath_literal(c)
    _ => raise err("E_REGEX", "unsupported regular expression escape")
  }
}

///|
fn XPathParser::class_unit(
  p : XPathParser,
) -> XPathSet raise @types.EngineError {
  let c = p.take()
  if c == '\\' {
    p.escape()
  } else if c == '[' || c == ']' {
    raise err("E_REGEX", "invalid character class")
  } else {
    xpath_literal(c)
  }
}

///|
fn XPathParser::char_class(
  p : XPathParser,
) -> XPathSet raise @types.EngineError {
  p.depth += 1
  if p.depth > 128 {
    raise err("E_REGEX", "character class nesting limit exceeded")
  }
  let neg = p.peek() == '^'
  if neg {
    ignore(p.take())
  }
  let members : Array[XPathSet] = []
  while p.peek() != ']' {
    if p.peek() == '-' &&
      p.pos + 1 < p.chars.length() &&
      p.chars[p.pos + 1] == '[' {
      if members.is_empty() {
        raise err("E_REGEX", "empty subtraction base")
      }
      ignore(p.take())
      ignore(p.take())
      let base = if neg { Negate(Union(members)) } else { Union(members) }
      let sub = p.char_class()
      p.expect(']')
      p.depth -= 1
      return Subtract(base, sub)
    }
    let first = p.class_unit()
    if p.peek() == '-' &&
      p.pos + 1 < p.chars.length() &&
      p.chars[p.pos + 1] != '[' &&
      p.chars[p.pos + 1] != ']' {
      ignore(p.take())
      let last = p.class_unit()
      match (first, last) {
        (Span(a, b), Span(c, d)) if a == b && c == d && a <= c =>
          members.push(Span(a, c))
        _ => raise err("E_REGEX", "invalid character range")
      }
    } else {
      members.push(first)
    }
  }
  p.expect(']')
  if members.is_empty() {
    raise err("E_REGEX", "empty character class")
  }
  p.depth -= 1
  if neg {
    Negate(Union(members))
  } else {
    Union(members)
  }
}

///|
fn XPathParser::number(p : XPathParser) -> Int32 raise @types.EngineError {
  let mut n = 0
  let start = p.pos
  while p.peek() >= '0' && p.peek() <= '9' {
    let digit = p.take().to_int() - 48
    n = n * 10 + digit
    if n > 10000 {
      raise err("E_REGEX", "repetition limit exceeded")
    }
  }
  if p.pos == start {
    raise err("E_REGEX", "expected repetition count")
  }
  n
}

///|
fn XPathParser::expression(p : XPathParser) -> XPathRE raise @types.EngineError {
  let choices : Array[XPathRE] = []
  let mut sequence : Array[XPathRE] = []
  while p.pos < p.chars.length() && p.peek() != ')' {
    if p.peek() == '|' {
      ignore(p.take())
      choices.push(Sequence(sequence))
      sequence = []
      continue
    }
    let c = p.take()
    let atom = match c {
      '(' => {
        p.depth += 1
        if p.depth > 128 {
          raise err("E_REGEX", "regular expression nesting limit exceeded")
        }
        let capture = p.peek() != '?'
        if !capture {
          p.expect('?')
          p.expect(':')
        }
        let id = if capture {
          p.groups += 1
          p.groups
        } else {
          0
        }
        let inner = p.expression()
        p.expect(')')
        p.depth -= 1
        if capture {
          p.closed[id] = true
          Capture(id, inner)
        } else {
          inner
        }
      }
      '[' => Character(p.char_class())
      '.' => Character(Negate(Union([])))
      '^' => Start
      '$' => End
      '\\' =>
        if p.peek() >= '1' && p.peek() <= '9' {
          let mut id = p.take().to_int() - 48
          while p.peek() >= '0' &&
                p.peek() <= '9' &&
                id * 10 + p.peek().to_int() - 48 <= p.groups {
            id = id * 10 + p.take().to_int() - 48
          }
          if !p.closed.contains(id) {
            raise err("E_REGEX", "invalid backreference")
          }
          Reference(id)
        } else {
          Character(p.escape())
        }
      '*' | '+' | '?' | '{' | '}' | ']' =>
        raise err("E_REGEX", "unexpected metacharacter")
      _ => Character(xpath_literal(c))
    }
    let quantified = match p.peek() {
      '*' => {
        ignore(p.take())
        Repeat(atom, 0, None)
      }
      '+' => {
        ignore(p.take())
        Repeat(atom, 1, None)
      }
      '?' => {
        ignore(p.take())
        Repeat(atom, 0, Some(1))
      }
      '{' => {
        ignore(p.take())
        let low = p.number()
        let high = if p.peek() == ',' {
          ignore(p.take())
          if p.peek() == '}' {
            None
          } else {
            Some(p.number())
          }
        } else {
          Some(low)
        }
        p.expect('}')
        if high is Some(h) && h < low {
          raise err("E_REGEX", "invalid repetition bounds")
        }
        Repeat(atom, low, high)
      }
      _ => atom
    }
    if p.peek() == '?' {
      ignore(p.take())
    }
    sequence.push(quantified)
  }
  choices.push(Sequence(sequence))
  Choice(choices)
}

///|
fn xpath_set_matches(s : XPathSet, c : Char, insensitive : Bool) -> Bool {
  match s {
    Span(a, b) => {
      let code = c.to_int()
      if code >= a && code <= b {
        return true
      }
      if !insensitive {
        return false
      }
      let key = xpath_folds.get(code).unwrap_or(code)
      xpath_variants
      .get(key)
      .unwrap_or([code])
      .iter()
      .any(v => v >= a && v <= b)
    }
    Property(re) => re.execute(c.to_string()) is Some(_)
    Union(xs) => xs.iter().any(x => xpath_set_matches(x, c, insensitive))
    Negate(x) => !xpath_set_matches(x, c, insensitive)
    Subtract(a, b) =>
      xpath_set_matches(a, c, insensitive) &&
      !xpath_set_matches(b, c, insensitive)
  }
}

///|
priv struct XPathState {
  pos : Int32
  captures : Map[Int32, Array[Char]]
}

///|
priv struct XPathMatch {
  input : Array[Char]
  insensitive : Bool
  multiline : Bool
  mut budget : Int32
}

///|
fn xpath_run(
  re : XPathRE,
  state : XPathState,
  ctx : XPathMatch,
) -> Array[XPathState] raise @types.EngineError {
  ctx.budget -= 1
  if ctx.budget < 0 {
    raise err("E_REGEX", "regular expression work limit exceeded")
  }
  let pos = state.pos
  let input = ctx.input
  match re {
    Character(s) =>
      if pos < input.length() &&
        xpath_set_matches(s, input[pos], ctx.insensitive) {
        [{ pos: pos + 1, captures: state.captures, }]
      } else {
        []
      }
    Start =>
      if pos == 0 ||
        (ctx.multiline && pos < input.length() && input[pos - 1] == '\n') {
        [state]
      } else {
        []
      }
    End =>
      if (
          pos == input.length() &&
          (!ctx.multiline || pos == 0 || input[pos - 1] != '\n')
        ) ||
        (ctx.multiline && pos < input.length() && input[pos] == '\n') {
        [state]
      } else {
        []
      }
    Sequence(xs) => {
      let mut states = [state]
      for x in xs {
        let next : Array[XPathState] = []
        for s in states {
          next.append(xpath_run(x, s, ctx))
        }
        states = next
      }
      states
    }
    Choice(xs) => {
      let out : Array[XPathState] = []
      for x in xs {
        out.append(xpath_run(x, state, ctx))
      }
      out
    }
    Capture(id, inner) =>
      xpath_run(inner, state, ctx).map(s => {
        let captures = s.captures.copy()
        captures[id] = input[pos:s.pos].to_owned()
        { pos: s.pos, captures, }
      })
    Reference(id) => {
      let captured = state.captures.get(id).unwrap_or([])
      if pos + captured.length() > input.length() {
        return []
      }
      for i, c in captured {
        if !xpath_set_matches(xpath_literal(c), input[pos + i], ctx.insensitive) {
          return []
        }
      }
      [{ pos: pos + captured.length(), captures: state.captures, }]
    }
    Repeat(inner, low, high) => {
      let out : Array[XPathState] = []
      let mut states = [state]
      let limit = high.unwrap_or(input.length() + low + 1)
      for count = 0; count <= limit && !states.is_empty(); count = count + 1 {
        if count >= low {
          out.append(states)
        }
        if count == limit {
          break
        }
        let next : Array[XPathState] = []
        for s in states {
          for n in xpath_run(inner, s, ctx) {
            if n.pos != s.pos || count < low {
              next.push(n)
            }
          }
        }
        states = next
      }
      out
    }
  }
}

///|
fn xpath_matches(
  input : String,
  pattern : String,
  flags : String,
) -> Bool raise @types.EngineError {
  if pattern.length() > 4096 {
    raise err("E_REGEX", "pattern length limit exceeded")
  }
  for c in flags.to_array() {
    if !"ismx".contains(c.to_string()) {
      raise err("E_REGEX", "unknown regular expression flag")
    }
  }
  // Normalize free spacing and dot before parsing, preserving nested classes.
  let chars : Array[Char] = []
  let mut depth = 0
  let mut escaped = false
  for c in pattern.to_array() {
    if flags.contains("x") &&
      depth == 0 &&
      (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      continue
    }
    if !escaped && c == '[' {
      depth += 1
    }
    if !escaped && c == ']' {
      depth -= 1
    }
    if !escaped && depth == 0 && c == '.' && !flags.contains("s") {
      chars.append(['[', '^', '\n', '\r', ']'])
    } else {
      chars.push(c)
    }
    escaped = !escaped && c == '\\'
  }
  let parser : XPathParser = { chars, pos: 0, groups: 0, depth: 0, closed: {}, }
  let re = parser.expression()
  if parser.pos != chars.length() {
    raise err("E_REGEX", "unmatched parenthesis")
  }
  let ctx : XPathMatch = {
    input: input.to_array(),
    insensitive: flags.contains("i"),
    multiline: flags.contains("m"),
    budget: 100000,
  }
  for pos = 0; pos <= ctx.input.length(); pos = pos + 1 {
    if !xpath_run(re, { pos, captures: {}, }, ctx).is_empty() {
      return true
    }
  }
  false
}
