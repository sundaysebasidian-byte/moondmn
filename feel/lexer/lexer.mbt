///|
/// A FEEL token. `text` holds the decoded payload for strings, temporal
/// literals and backtick names, the raw spelling for everything else.
pub struct Token {
  text : String
  kind : String
  line : Int32
  column : Int32
}

///|
fn slice(chars : Array[Char], start : Int32, end : Int32) -> String {
  String::from_array(chars[start:end].to_owned())
}

///|
fn word_char(ch : Char) -> Bool {
  name_start(ch) ||
  ch.is_ascii_digit() ||
  ch == '\u00B7' ||
  (ch.to_int() >= 0x300 && ch.to_int() <= 0x36F) ||
  (ch.to_int() >= 0x203F && ch.to_int() <= 0x2040)
}

///|
fn hex_value(ch : Char) -> Int32 {
  let code = ch.to_int()
  if code >= 48 && code <= 57 {
    code - 48
  } else if code >= 65 && code <= 70 {
    code - 55
  } else if code >= 97 && code <= 102 {
    code - 87
  } else {
    -1
  }
}

///|
/// Decode a FEEL string literal. FEEL supports `\n \r \t \b \f \" \\ \/ \'`
/// plus `\uXXXX` and `\UXXXXXX` (six hex digits) escapes.
fn decode_string(
  raw : String,
  line : Int32,
  column : Int32,
) -> String raise @types.EngineError {
  let chars = raw.to_array()
  let n = chars.length()
  if n < 2 || chars[0] != '"' || chars[n - 1] != '"' {
    raise @types.Failure("E_LEX", line, column, "invalid string literal")
  }
  let out = []
  let mut i = 1
  while i < n - 1 {
    let ch = chars[i]
    if ch != '\\' {
      out.push(ch)
      i = i + 1
      continue
    }
    if i + 1 >= n - 1 {
      raise @types.Failure("E_LEX", line, column, "unterminated escape")
    }
    let esc = chars[i + 1]
    if esc == 'n' {
      out.push('\n')
      i = i + 2
    } else if esc == 'r' {
      out.push('\r')
      i = i + 2
    } else if esc == 't' {
      out.push('\t')
      i = i + 2
    } else if esc == 'b' {
      out.push((8).unsafe_to_char())
      i = i + 2
    } else if esc == 'f' {
      out.push((12).unsafe_to_char())
      i = i + 2
    } else if esc == '"' {
      out.push('"')
      i = i + 2
    } else if esc == '\\' {
      out.push('\\')
      i = i + 2
    } else if esc == '/' {
      out.push('/')
      i = i + 2
    } else if esc == '\'' {
      out.push('\'')
      i = i + 2
    } else if (esc == 'u' || esc == 'U') &&
      i + 2 + (if esc == 'u' { 4 } else { 6 }) <= n - 1 {
      let digits = if esc == 'u' { 4 } else { 6 }
      let mut code = 0
      let mut valid = true
      for k = 0; k < digits; k = k + 1 {
        let h = hex_value(chars[i + 2 + k])
        if h < 0 {
          valid = false
        } else {
          code = code * 16 + h
        }
      }
      if valid && code <= 0x10FFFF {
        out.push(code.unsafe_to_char())
        i = i + 2 + digits
      } else {
        out.push('\\')
        out.push(esc)
        i = i + 2
      }
    } else {
      out.push('\\')
      out.push(esc)
      i = i + 2
    }
  }
  String::from_array(out)
}

///|
/// Scan a double quoted string starting at the opening quote. Returns the
/// index just after the closing quote.
fn scan_string(
  chars : Array[Char],
  start : Int32,
  line : Int32,
  column : Int32,
) -> Int32 raise @types.EngineError {
  let mut i = start + 1
  let mut closed = false
  while i < chars.length() {
    let ch = chars[i]
    if ch == '\n' || ch == '\r' {
      raise @types.Failure("E_LEX", line, column, "newline in string")
    }
    if ch == '\\' {
      if i + 1 >= chars.length() {
        raise @types.Failure("E_LEX", line, column, "unterminated escape")
      }
      i = i + 2
    } else if ch == '"' {
      i = i + 1
      closed = true
      break
    } else {
      i = i + 1
    }
  }
  if !closed {
    raise @types.Failure("E_LEX", line, column, "unterminated string")
  }
  i
}

///|
fn space_char(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
/// Length of `name` at `at` when whitespace in `name` matches one or more
/// whitespace characters in the source, or -1 when it does not match.
fn name_at(chars : Array[Char], at : Int32, name : String) -> Int32 {
  let ns = name.to_array()
  let mut i = at
  let mut k = 0
  while k < ns.length() {
    if ns[k] == ' ' {
      if i >= chars.length() || !space_char(chars[i]) {
        return -1
      }
      while i < chars.length() && space_char(chars[i]) {
        i = i + 1
      }
      k = k + 1
    } else {
      if i >= chars.length() || chars[i] != ns[k] {
        return -1
      }
      i = i + 1
      k = k + 1
    }
  }
  i - at
}

///|
/// Length of the longest known name starting at `at`, or zero.
fn known_length(
  chars : Array[Char],
  at : Int32,
  names : Array[String],
) -> Int32 {
  if at > 0 && word_char(chars[at - 1]) {
    return 0
  }
  let mut best = 0
  for name in names {
    let n = name_at(chars, at, name)
    if n > best {
      let end = at + n
      if end >= chars.length() || !word_char(chars[end]) {
        best = n
      }
    }
  }
  best
}

///|
/// Replace runs of whitespace with a single space so that multi-word names
/// split across lines match their canonical spelling.
fn collapse_spaces(text : String) -> String {
  let chars = text.to_array()
  let out = StringBuilder()
  let mut pending = false
  let mut wrote = false
  for ch in chars {
    if space_char(ch) {
      pending = true
    } else {
      if pending && wrote {
        out.write_char(' ')
      }
      pending = false
      wrote = true
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
/// Tokenize FEEL using longest scoped names; failures include source positions.
pub fn lex(
  source : String,
  names : Array[String],
  properties~ : Array[String] = [],
) -> Array[Token] raise @types.EngineError {
  let chars = source.to_array()
  let scoped_properties = names.copy()
  scoped_properties.append(properties)
  if chars.length() > 100000 {
    raise @types.fail("E_LIMIT", "expression too long")
  }
  let out = []
  let mut i = 0
  let mut line = 1
  let mut col = 1
  while i < chars.length() {
    let ch = chars[i]
    if ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' {
      if ch == '\n' {
        line = line + 1
        col = 1
      } else {
        col = col + 1
      }
      i = i + 1
      continue
    }
    if ch == '/' && i + 1 < chars.length() && chars[i + 1] == '/' {
      i = i + 2
      while i < chars.length() && chars[i] != '\n' {
        i = i + 1
      }
      col = col + 1
      continue
    }
    if ch == '/' && i + 1 < chars.length() && chars[i + 1] == '*' {
      let start_line = line
      let start_col = col
      i = i + 2
      let mut closed = false
      while i + 1 < chars.length() {
        if chars[i] == '*' && chars[i + 1] == '/' {
          i = i + 2
          closed = true
          break
        }
        if chars[i] == '\n' {
          line = line + 1
          col = 1
        } else {
          col = col + 1
        }
        i = i + 1
      }
      if !closed {
        raise @types.Failure(
          "E_LEX", start_line, start_col, "unterminated comment",
        )
      }
      col = col + 1
      continue
    }
    let start = i
    let start_line = line
    let start_col = col
    let mut kind = "symbol"
    if ch == '"' {
      kind = "string"
      i = scan_string(chars, i, line, col)
    } else if ch == '@' && i + 1 < chars.length() && chars[i + 1] == '"' {
      kind = "temporal"
      let end = scan_string(chars, i + 1, line, col)
      let raw = slice(chars, i + 1, end)
      out.push({ text: decode_string(raw, line, col), kind, line, column: col, })
      col = col + (end - i)
      i = end
      continue
    } else if ch == '`' {
      kind = "name"
      i = i + 1
      let mut closed = false
      while i < chars.length() {
        if chars[i] == '\n' || chars[i] == '\r' {
          raise @types.Failure("E_LEX", line, col, "newline in name")
        }
        if chars[i] == '`' {
          i = i + 1
          closed = true
          break
        }
        i = i + 1
      }
      if !closed {
        raise @types.Failure("E_LEX", line, col, "unterminated name")
      }
    } else if (ch >= '0' && ch <= '9') ||
      (
        ch == '.' &&
        i + 1 < chars.length() &&
        chars[i + 1] >= '0' &&
        chars[i + 1] <= '9'
      ) {
      kind = "number"
      if ch == '.' {
        i = i + 1
      }
      while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
        i = i + 1
      }
      if i < chars.length() &&
        chars[i] == '.' &&
        !(i + 1 < chars.length() && chars[i + 1] == '.') {
        i = i + 1
        while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
          i = i + 1
        }
      }
      if i < chars.length() && (chars[i] == 'e' || chars[i] == 'E') {
        let mut j = i + 1
        if j < chars.length() && (chars[j] == '+' || chars[j] == '-') {
          j = j + 1
        }
        if j < chars.length() && chars[j] >= '0' && chars[j] <= '9' {
          i = j
          while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
            i = i + 1
          }
        }
      }
    } else if ch == '?' {
      kind = "name"
      i = i + 1
    } else if known_length(
        chars,
        i,
        if out.get(out.length() - 1) is Some(t) && t.text == "." {
          scoped_properties
        } else {
          names
        },
      ) >
      0 {
      kind = "name"
      i = i +
        known_length(
          chars,
          i,
          if out.get(out.length() - 1) is Some(t) && t.text == "." {
            scoped_properties
          } else {
            names
          },
        )
    } else if name_start(ch) || ch == '_' {
      kind = "name"
      i = i + 1
      while i < chars.length() && word_char(chars[i]) {
        i = i + 1
      }
    } else {
      i = i + 1
      if i < chars.length() &&
        (
          (ch == '<' && (chars[i] == '=' || chars[i] == '>')) ||
          (ch == '>' && chars[i] == '=') ||
          (ch == '!' && chars[i] == '=') ||
          (ch == '.' && chars[i] == '.') ||
          (ch == '*' && chars[i] == '*')
        ) {
        i = i + 1
      }
    }
    if kind == "string" {
      let raw = slice(chars, start, i)
      out.push({
        text: decode_string(raw, start_line, start_col),
        kind: "string",
        line: start_line,
        column: start_col,
      })
    } else if kind == "name" && ch == '`' {
      out.push({
        text: slice(chars, start + 1, i - 1),
        kind,
        line: start_line,
        column: start_col,
      })
    } else {
      let raw = slice(chars, start, i)
      out.push({
        text: if kind == "name" {
          collapse_spaces(raw)
        } else {
          raw
        },
        kind,
        line: start_line,
        column: start_col,
      })
    }
    col = col + (i - start)
  }
  out.push({ text: "", kind: "eof", line, column: col, })
  out
}

///|
// DMN 1.5 FEEL grammar rule 28.
fn name_start(ch : Char) -> Bool {
  let c = ch.to_int()
  ch.is_ascii_alphabetic() ||
  ch == '_' ||
  (c >= 0xC0 && c <= 0xD6) ||
  (c >= 0xD8 && c <= 0xF6) ||
  (c >= 0xF8 && c <= 0x2FF) ||
  (c >= 0x370 && c <= 0x37D) ||
  (c >= 0x37F && c <= 0x1FFF) ||
  (c >= 0x200C && c <= 0x200D) ||
  (c >= 0x2070 && c <= 0x218F) ||
  (c >= 0x2C00 && c <= 0x2FEF) ||
  (c >= 0x3001 && c <= 0xD7FF) ||
  (c >= 0xF900 && c <= 0xFDCF) ||
  (c >= 0xFDF0 && c <= 0xFFFD) ||
  (c >= 0x10000 && c <= 0xEFFFF)
}
