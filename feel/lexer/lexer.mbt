///|
pub struct Token {
  text : String
  kind : String
  line : Int32
  column : Int32
}

///|
fn slice(chars : Array[Char], start : Int32, end : Int32) -> String {
  let b = StringBuilder()
  for i = start; i < end; i = i + 1 {
    b.write_char(chars[i])
  }
  b.to_string()
}

///|
pub fn lex(
  source : String,
  names : Array[String],
) -> Array[Token] raise @types.EngineError {
  let cs = source.to_array()
  if cs.length() > 100000 {
    raise @types.fail("E_LIMIT", "expression too long")
  }
  let out = []
  let mut i = 0
  let mut line = 1
  let mut col = 1
  while i < cs.length() {
    let ch = cs[i]
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
    let start = i
    let mut kind = "symbol"
    let mut known = 0
    for name in names {
      let ns = name.to_array()
      if ns.length() > known && i + ns.length() <= cs.length() {
        let mut same = true
        for k = 0; k < ns.length(); k = k + 1 {
          if cs[i + k] != ns[k] {
            same = false
          }
        }
        let end = i + ns.length()
        if end < cs.length() &&
          (
            cs[end].is_ascii_alphabetic() ||
            cs[end].is_ascii_digit() ||
            cs[end] == '_'
          ) {
          same = false
        }
        if same {
          known = ns.length()
        }
      }
    }
    if ch == '"' {
      kind = "string"
      i = i + 1
      let mut closed = false
      while i < cs.length() {
        if cs[i] == '\n' || cs[i] == '\r' {
          raise @types.Failure("E_LEX", line, col, "newline in string")
        }
        if cs[i] == '\\' {
          i = i + 2
        } else if cs[i] == '"' {
          i = i + 1
          closed = true
          break
        } else {
          i = i + 1
        }
      }
      if !closed {
        raise @types.Failure("E_LEX", line, col, "unterminated string")
      }
    } else if ch >= '0' && ch <= '9' {
      kind = "number"
      i = i + 1
      while i < cs.length() && cs[i].is_ascii_digit() {
        i = i + 1
      }
      if i + 1 < cs.length() && cs[i] == '.' && cs[i + 1].is_ascii_digit() {
        i = i + 1
        while i < cs.length() && cs[i].is_ascii_digit() {
          i = i + 1
        }
      }
    } else if known > 0 {
      kind = "name"
      i = i + known
    } else if ch.is_ascii_alphabetic() || ch == '_' || ch == '?' {
      kind = "name"
      i = i + 1
      while i < cs.length() &&
            (
              cs[i].is_ascii_alphabetic() ||
              cs[i].is_ascii_digit() ||
              cs[i] == '_'
            ) {
        i = i + 1
      }
    } else {
      i = i + 1
      if i < cs.length() &&
        (
          (ch == '<' && (cs[i] == '=' || cs[i] == '>')) ||
          (ch == '>' && cs[i] == '=') ||
          (ch == '.' && cs[i] == '.') ||
          (ch == '*' && cs[i] == '*')
        ) {
        i = i + 1
      }
    }
    out.push({ text: slice(cs, start, i), kind, line, column: col, })
    col = col + i - start
  }
  out.push({ text: "", kind: "eof", line, column: col, })
  out
}
