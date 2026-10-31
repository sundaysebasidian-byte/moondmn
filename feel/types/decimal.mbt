///|
/// Exact bounded decimal. Operations exceeding 34 significant digits are rejected
/// until Decimal128 rounding and exponent semantics are implemented.
pub struct Decimal {
  coefficient : @bigint.BigInt
  scale : Int32
} derive(Eq)

///|
pub(all) suberror EngineError {
  Failure(String, Int32, Int32, String)
} derive(Eq)

///|
pub fn fail(code : String, message : String) -> EngineError {
  Failure(code, 1, 1, message)
}

///|
fn power(n : Int32) -> @bigint.BigInt {
  @bigint.BigInt::from_int(10).pow(@bigint.BigInt::from_int(n))
}

///|
fn normalize(c : @bigint.BigInt, scale : Int32) -> Decimal raise EngineError {
  let mut c = c
  let mut s = scale
  while s > 0 && (c % 10N).is_zero() {
    c = c / 10N
    s = s - 1
  }
  let digits = c.to_string().replace(old="-", new="").length()
  if digits > 34 || s > 128 {
    raise fail("E_DECIMAL_RANGE", "decimal exceeds supported exact range")
  }
  { coefficient: c, scale: s, }
}

///|
pub fn decimal(text : String) -> Decimal raise EngineError {
  let chars = text.to_array()
  let digits = StringBuilder()
  let mut scale = 0
  let mut dot = false
  let mut count = 0
  for i, ch in chars {
    if ch == '-' && i == 0 {
      digits.write_char(ch)
    } else if ch == '.' && !dot {
      dot = true
    } else if ch >= '0' && ch <= '9' {
      digits.write_char(ch)
      count = count + 1
      if dot {
        scale = scale + 1
      }
    } else {
      raise fail("E_DECIMAL_SYNTAX", "invalid decimal: " + text)
    }
  }
  if count == 0 || chars.length() > 256 {
    raise fail("E_DECIMAL_SYNTAX", "invalid decimal")
  }
  normalize(@bigint.BigInt::from_string(digits.to_string()), scale)
}

///|
pub fn Decimal::text(self : Decimal) -> String {
  let negative = self.coefficient < 0N
  let mut raw = (if negative { -self.coefficient } else { self.coefficient }).to_string()
  while raw.length() <= self.scale {
    raw = "0" + raw
  }
  let out = StringBuilder()
  if negative {
    out.write_string("-")
  }
  for i, ch in raw.to_array() {
    if self.scale > 0 && i == raw.length() - self.scale {
      out.write_string(".")
    }
    out.write_char(ch)
  }
  out.to_string()
}

///|
pub fn Decimal::add(a : Decimal, b : Decimal) -> Decimal raise EngineError {
  let scale = if a.scale > b.scale { a.scale } else { b.scale }
  normalize(
    a.coefficient * power(scale - a.scale) +
    b.coefficient * power(scale - b.scale),
    scale,
  )
}

///|
pub fn Decimal::negate(a : Decimal) -> Decimal {
  { coefficient: -a.coefficient, scale: a.scale, }
}

///|
pub fn Decimal::multiply(a : Decimal, b : Decimal) -> Decimal raise EngineError {
  normalize(a.coefficient * b.coefficient, a.scale + b.scale)
}

///|
pub fn Decimal::compare(a : Decimal, b : Decimal) -> Int32 {
  let scale = if a.scale > b.scale { a.scale } else { b.scale }
  (a.coefficient * power(scale - a.scale)).compare(
    b.coefficient * power(scale - b.scale),
  )
}

///|
pub fn Decimal::divide(a : Decimal, b : Decimal) -> Decimal raise EngineError {
  if b.coefficient.is_zero() {
    raise fail("E_DIV_ZERO", "division by zero")
  }
  let numerator = a.coefficient * power(b.scale + 34)
  let denominator = b.coefficient * power(a.scale)
  if !(numerator % denominator).is_zero() {
    raise fail(
      "E_DECIMAL_ROUNDING", "nonterminating division requires Decimal128 rounding",
    )
  }
  normalize(numerator / denominator, 34)
}

///|
pub extend Decimal with Eq::{equal, not_equal}

///|
pub extend EngineError with Eq::{equal, not_equal}
