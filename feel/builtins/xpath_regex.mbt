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
  Repeat(XPathRE, Int32, Int32?, Bool)
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
    let mut quantified = match p.peek() {
      '*' => {
        ignore(p.take())
        Repeat(atom, 0, None, false)
      }
      '+' => {
        ignore(p.take())
        Repeat(atom, 1, None, false)
      }
      '?' => {
        ignore(p.take())
        Repeat(atom, 0, Some(1), false)
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
        Repeat(atom, low, high, false)
      }
      _ => atom
    }
    if p.peek() == '?' {
      ignore(p.take())
      if quantified is Repeat(inner, low, high, _) {
        quantified = Repeat(inner, low, high, true)
      }
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
      xpath_variants
      .get(code)
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
priv enum XPathInstruction {
  Consume(XPathSet, Int32)
  AssertStart(Int32)
  AssertEnd(Int32)
  Fork(Int32, Int32)
  Open(Int32, Int32)
  Close(Int32, Int32)
  Backref(Int32, Int32)
  Accept
}

///|
fn xpath_compile(
  re : XPathRE,
  next : Int32,
  code : Array[XPathInstruction],
) -> Int32 raise @types.EngineError {
  if code.length() > 100000 {
    raise err("E_REGEX", "compiled instruction limit exceeded")
  }
  let instruction = match re {
    Character(s) => Consume(s, next)
    Start => AssertStart(next)
    End => AssertEnd(next)
    Reference(id) => Backref(id, next)
    Capture(id, inner) => {
      let close = code.length()
      code.push(Close(id, next))
      Open(id, xpath_compile(inner, close, code))
    }
    Sequence(xs) => {
      let mut entry = next
      for i = xs.length() - 1; i >= 0; i = i - 1 {
        entry = xpath_compile(xs[i], entry, code)
      }
      return entry
    }
    Choice(xs) => {
      let mut entry = xpath_compile(xs[xs.length() - 1], next, code)
      for i = xs.length() - 2; i >= 0; i = i - 1 {
        let first = xpath_compile(xs[i], next, code)
        let at = code.length()
        code.push(Fork(first, entry))
        entry = at
      }
      return entry
    }
    Repeat(inner, low, high, reluctant) => {
      let mut entry = next
      match high {
        None => {
          let fork = code.length()
          code.push(Accept)
          let body = xpath_compile(inner, fork, code)
          code[fork] = if reluctant {
            Fork(next, body)
          } else {
            Fork(body, next)
          }
          entry = fork
        }
        Some(h) =>
          for i = low; i < h; i = i + 1 {
            let body = xpath_compile(inner, entry, code)
            let fork = code.length()
            code.push(
              if reluctant {
                Fork(entry, body)
              } else {
                Fork(body, entry)
              },
            )
            entry = fork
          }
      }
      for i = 0; i < low; i = i + 1 {
        entry = xpath_compile(inner, entry, code)
      }
      return entry
    }
  }
  let entry = code.length()
  code.push(instruction)
  entry
}

///|
fn xpath_find(
  code : Array[XPathInstruction],
  entry : Int32,
  ctx : XPathMatch,
  from : Int32,
) -> (Int32, XPathState)? raise @types.EngineError {
  let references = code.iter().any(i => i is Backref(_, _))
  let seen : Map[(Int32, Int32), Bool] = Map([])
  let captured_seen : Map[(Int32, Int32, String), Bool] = Map([])
  for start = from; start <= ctx.input.length(); start = start + 1 {
    ctx.budget = 10000000
    let stack : Array[(Int32, XPathState, Map[Int32, Int32])] = [
      (entry, { pos: start, captures: {}, }, {}),
    ]
    while !stack.is_empty() {
      let (pc, state, opens) = stack.pop().unwrap()
      let pos = state.pos
      ctx.budget -= 1
      if ctx.budget < 0 {
        raise err("E_REGEX", "regular expression work limit exceeded")
      }
      if !references {
        if seen.contains((pc, pos)) {
          continue
        }
        seen[(pc, pos)] = true
      }
      if references {
        let key = StringBuilder()
        let ids = state.captures.keys().to_array()
        ids.sort()
        for id in ids {
          let chars = state.captures.get(id).unwrap()
          key.write_string("\{id}:\{chars.length()}:")
          for c in chars {
            key.write_char(c)
          }
        }
        key.write_char('|')
        let ids = opens.keys().to_array()
        ids.sort()
        for id in ids {
          key.write_string("\{id}:\{opens.get(id).unwrap()};")
        }
        let fingerprint = (pc, pos, key.to_string())
        if captured_seen.contains(fingerprint) {
          continue
        }
        captured_seen[fingerprint] = true
      }
      match code[pc] {
        Accept => return Some((start, state))
        Fork(a, b) => {
          stack.push((b, state, opens))
          stack.push((a, state, opens))
        }
        Consume(s, next) =>
          if pos < ctx.input.length() &&
            xpath_set_matches(s, ctx.input[pos], ctx.insensitive) {
            stack.push(
              (next, { pos: pos + 1, captures: state.captures, }, opens),
            )
          }
        AssertStart(next) =>
          if pos == 0 ||
            (
              ctx.multiline &&
              pos < ctx.input.length() &&
              ctx.input[pos - 1] == '\n'
            ) {
            stack.push((next, state, opens))
          }
        AssertEnd(next) =>
          if (
              pos == ctx.input.length() &&
              (!ctx.multiline || pos == 0 || ctx.input[pos - 1] != '\n')
            ) ||
            (
              ctx.multiline &&
              pos < ctx.input.length() &&
              ctx.input[pos] == '\n'
            ) {
            stack.push((next, state, opens))
          }
        Open(id, next) => {
          let updated = opens.copy()
          updated[id] = pos
          stack.push((next, state, updated))
        }
        Close(id, next) => {
          let captures = state.captures.copy()
          captures[id] = ctx.input[opens.get(id).unwrap():pos].to_owned()
          stack.push((next, { pos, captures, }, opens))
        }
        Backref(id, next) => {
          let captured = state.captures.get(id).unwrap_or([])
          let mut matches = pos + captured.length() <= ctx.input.length()
          if matches {
            for i, c in captured {
              if !xpath_set_matches(
                  xpath_literal(c),
                  ctx.input[pos + i],
                  ctx.insensitive,
                ) {
                matches = false
                break
              }
            }
          }
          if matches {
            stack.push(
              (
                next,
                { pos: pos + captured.length(), captures: state.captures, },
                opens,
              ),
            )
          }
        }
      }
    }
  }
  None
}

///|
fn xpath_program(
  pattern : String,
  flags : String,
) -> (Array[XPathInstruction], Int32, Int32) raise @types.EngineError {
  if pattern.length() > 4096 {
    raise err("E_REGEX", "pattern length limit exceeded")
  }
  for c in flags.to_array() {
    if !"ismxq".contains(c.to_string()) {
      raise err("E_REGEX", "unknown regular expression flag")
    }
  }
  if flags.contains("q") {
    let literals = pattern.to_array().map(c => Character(xpath_literal(c)))
    let code = [Accept]
    let entry = xpath_compile(Sequence(literals), 0, code)
    return (code, entry, 0)
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
  let code = [Accept]
  let entry = xpath_compile(re, 0, code)
  if code.length() > 100000 {
    raise err("E_REGEX", "compiled instruction limit exceeded")
  }
  (code, entry, parser.groups)
}

///|
fn xpath_context(input : String, flags : String) -> XPathMatch {
  {
    input: input.to_array(),
    insensitive: flags.contains("i"),
    multiline: flags.contains("m") && !flags.contains("q"),
    budget: 10000000,
  }
}

///|
fn xpath_matches(
  input : String,
  pattern : String,
  flags : String,
) -> Bool raise @types.EngineError {
  let (code, entry, _) = xpath_program(pattern, flags)
  xpath_find(code, entry, xpath_context(input, flags), 0) is Some(_)
}

///|
fn xpath_parts(
  input : String,
  pattern : String,
  flags : String,
  replacement : String?,
) -> Array[String] raise @types.EngineError {
  let (code, entry, groups) = xpath_program(pattern, flags)
  if xpath_find(code, entry, xpath_context("", flags), 0) is Some(_) {
    raise err("E_REGEX", "pattern matches zero length string")
  }
  // Validate replacement even when the input has no match.
  if !flags.contains("q") && replacement is Some(r) {
    ignore(xpath_replacement(r, {}, groups))
  }
  let ctx = xpath_context(input, flags)
  let out : Array[String] = []
  let mut from = 0
  while from <= ctx.input.length() {
    match xpath_find(code, entry, ctx, from) {
      None => break
      Some((start, state)) => {
        if start == state.pos {
          raise err("E_REGEX", "zero length match")
        }
        out.push(String::from_array(ctx.input[from:start].to_owned()))
        if replacement is Some(r) {
          let captures = state.captures.copy()
          captures[0] = ctx.input[start:state.pos].to_owned()
          out.push(
            if flags.contains("q") {
              r
            } else {
              xpath_replacement(r, captures, groups)
            },
          )
        }
        from = state.pos
      }
    }
  }
  out.push(String::from_array(ctx.input[from:].to_owned()))
  out
}

///|
fn xpath_replacement(
  source : String,
  captures : Map[Int32, Array[Char]],
  groups : Int32,
) -> String raise @types.EngineError {
  let chars = source.to_array()
  let out = StringBuilder()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    i += 1
    if c == '\\' {
      if i == chars.length() || (chars[i] != '\\' && chars[i] != '$') {
        raise err("E_REGEX", "invalid replacement escape")
      }
      out.write_char(chars[i])
      i += 1
    } else if c == '$' {
      if i == chars.length() || chars[i] < '0' || chars[i] > '9' {
        raise err("E_REGEX", "invalid replacement group")
      }
      let mut id = 0
      let mut chosen = 0
      let mut consumed = i
      let first = i
      while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
        id = if id > 10000 { 100001 } else { id * 10 + chars[i].to_int() - 48 }
        i += 1
        if id <= groups || id <= 9 {
          chosen = id
          consumed = i
        }
      }
      if consumed == first {
        raise err("E_REGEX", "invalid replacement group")
      }
      for ch in captures.get(chosen).unwrap_or([]) {
        out.write_char(ch)
      }
      for j = consumed; j < i; j = j + 1 {
        out.write_char(chars[j])
      }
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}
