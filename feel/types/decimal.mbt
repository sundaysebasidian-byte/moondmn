///|
/// Exact signed decimal with at most 34 significant digits (DMN number type).
/// Division and out-of-range arithmetic are rounded half-to-even, the same
/// rounding mode required by IEEE 754 decimal128.
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
pub fn fail_at(
  code : String,
  line : Int32,
  column : Int32,
  message : String,
) -> EngineError {
  Failure(code, line, column, message)
}

///|
pub fn error_code(e : EngineError) -> String {
  match e {
    Failure(code, _, _, _) => code
  }
}

///|
pub fn error_message(e : EngineError) -> String {
  match e {
    Failure(_, _, _, message) => message
  }
}

///|
pub let max_digits : Int32 = 34

///|
fn pow10(n : Int32) -> @bigint.BigInt {
  @bigint.BigInt::from_int(10).pow(@bigint.BigInt::from_int(n))
}

///|
fn digit_count(c : @bigint.BigInt) -> Int32 {
  let s = if c < 0N { (-c).to_string() } else { c.to_string() }
  s.length()
}

///|
/// Divide and round half-to-even to an integer.
fn div_half_even(n : @bigint.BigInt, d : @bigint.BigInt) -> @bigint.BigInt {
  if d.is_zero() {
    return 0N
  }
  let negative = (n < 0N) != (d < 0N)
  let a = if n < 0N { -n } else { n }
  let b = if d < 0N { -d } else { d }
  let q = a / b
  let r = a % b
  let twice = r * 2N
  let rounded = if twice > b {
    q + 1N
  } else if twice < b {
    q
  } else if (q % 2N).is_zero() {
    q
  } else {
    q + 1N
  }
  if negative {
    -rounded
  } else {
    rounded
  }
}

///|
/// Remove insignificant trailing zeros, then round to 34 significant digits.
fn normalize(c : @bigint.BigInt, scale : Int32) -> Decimal raise EngineError {
  let mut c = c
  let mut s = scale
  if s < 0 {
    c = c * pow10(-s)
    s = 0
  }
  while s > 0 && (c % 10N).is_zero() {
    c = c / 10N
    s = s - 1
  }
  let mut digits = digit_count(c)
  while digits > max_digits {
    let drop = digits - max_digits
    c = div_half_even(c, pow10(drop))
    s = s - drop
    if s < 0 {
      raise fail("E_DECIMAL_RANGE", "decimal exponent exceeds supported range")
    }
    digits = digit_count(c)
  }
  if s > 128 {
    raise fail("E_DECIMAL_RANGE", "decimal exponent exceeds supported range")
  }
  { coefficient: c, scale: s, }
}

///|
/// Parse a decimal literal. Accepts an optional sign, a leading dot, and a
/// decimal exponent. Values with more than 34 significant digits are rounded.
pub fn decimal(text : String) -> Decimal raise EngineError {
  let chars = text.to_array()
  if chars.is_empty() || chars.length() > 512 {
    raise fail("E_DECIMAL_SYNTAX", "invalid decimal: " + text)
  }
  let digits = StringBuilder()
  let mut scale = 0
  let mut exp = 0
  let mut exp_sign = 1
  let mut i = 0
  let mut dot = false
  let mut exponent = false
  let mut count = 0
  if chars[0] == '-' || chars[0] == '+' {
    if chars[0] == '-' {
      digits.write_char('-')
    }
    i = 1
  }
  while i < chars.length() {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      if exponent {
        exp = exp * 10 + (ch.to_int() - 48)
        if exp > 128 {
          raise fail("E_DECIMAL_RANGE", "decimal exponent too large")
        }
      } else {
        digits.write_char(ch)
        count = count + 1
        if dot {
          scale = scale + 1
        }
      }
    } else if ch == '.' && !dot && !exponent {
      dot = true
    } else if (ch == 'e' || ch == 'E') && !exponent && count > 0 {
      exponent = true
      if i + 1 < chars.length() && (chars[i + 1] == '-' || chars[i + 1] == '+') {
        if chars[i + 1] == '-' {
          exp_sign = -1
        }
        i = i + 1
      }
    } else {
      raise fail("E_DECIMAL_SYNTAX", "invalid decimal: " + text)
    }
    i = i + 1
  }
  if count == 0 {
    raise fail("E_DECIMAL_SYNTAX", "invalid decimal: " + text)
  }
  normalize(
    @bigint.BigInt::from_string(digits.to_string()),
    scale - exp_sign * exp,
  )
}

///|
pub fn decimal_int(n : Int32) -> Decimal {
  { coefficient: @bigint.BigInt::from_int(n), scale: 0, }
}

///|
pub fn decimal_int64(n : Int64) -> Decimal {
  { coefficient: @bigint.BigInt::from_int64(n), scale: 0, }
}

///|
pub fn zero() -> Decimal {
  { coefficient: 0N, scale: 0, }
}

///|
pub fn Decimal::is_zero(self : Decimal) -> Bool {
  self.coefficient.is_zero()
}

///|
pub fn Decimal::is_negative(self : Decimal) -> Bool {
  self.coefficient < 0N
}

///|
pub fn Decimal::is_integer(self : Decimal) -> Bool {
  self.scale == 0
}

///|
pub fn Decimal::text(self : Decimal) -> String {
  if self.coefficient.is_zero() {
    return "0"
  }
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
    a.coefficient * pow10(scale - a.scale) +
    b.coefficient * pow10(scale - b.scale),
    scale,
  )
}

///|
pub fn Decimal::negate(a : Decimal) -> Decimal {
  { coefficient: -a.coefficient, scale: a.scale, }
}

///|
pub fn Decimal::abs(a : Decimal) -> Decimal {
  if a.coefficient < 0N {
    a.negate()
  } else {
    a
  }
}

///|
pub fn Decimal::multiply(a : Decimal, b : Decimal) -> Decimal raise EngineError {
  normalize(a.coefficient * b.coefficient, a.scale + b.scale)
}

///|
pub fn Decimal::compare(a : Decimal, b : Decimal) -> Int32 {
  let scale = if a.scale > b.scale { a.scale } else { b.scale }
  (a.coefficient * pow10(scale - a.scale)).compare(
    b.coefficient * pow10(scale - b.scale),
  )
}

///|
pub fn Decimal::divide(a : Decimal, b : Decimal) -> Decimal raise EngineError {
  if b.coefficient.is_zero() {
    raise fail("E_DIV_ZERO", "division by zero")
  }
  let extra = 40 + a.scale
  let numerator = a.coefficient * pow10(b.scale + extra)
  let denominator = b.coefficient * pow10(a.scale)
  normalize(numerator / denominator, extra)
}

///|
/// Floored integer division used by modulo.
fn floor_div(a : @bigint.BigInt, b : @bigint.BigInt) -> @bigint.BigInt {
  let q = a / b
  let r = a % b
  if !r.is_zero() && (r < 0N) != (b < 0N) {
    q - 1N
  } else {
    q
  }
}

///|
pub fn Decimal::modulo(a : Decimal, b : Decimal) -> Decimal raise EngineError {
  if b.coefficient.is_zero() {
    raise fail("E_DIV_ZERO", "modulo by zero")
  }
  let scale = if a.scale > b.scale { a.scale } else { b.scale }
  let x = a.coefficient * pow10(scale - a.scale)
  let y = b.coefficient * pow10(scale - b.scale)
  normalize(x - floor_div(x, y) * y, scale)
}

///|
pub fn Decimal::floor(self : Decimal) -> Decimal raise EngineError {
  if self.scale == 0 {
    return self
  }
  let q = floor_div(self.coefficient, pow10(self.scale))
  normalize(q, 0)
}

///|
pub fn Decimal::ceiling(self : Decimal) -> Decimal raise EngineError {
  if self.scale == 0 {
    return self
  }
  let q = floor_div(self.coefficient, pow10(self.scale))
  let r = self.coefficient - q * pow10(self.scale)
  normalize(if r.is_zero() { q } else { q + 1N }, 0)
}

///|
pub fn Decimal::truncate(self : Decimal) -> Decimal raise EngineError {
  if self.scale == 0 {
    return self
  }
  normalize(self.coefficient / pow10(self.scale), 0)
}

///|
pub fn Decimal::to_int(self : Decimal) -> Int32 raise EngineError {
  if self.scale != 0 {
    raise fail("E_TYPE", "value is not an integer")
  }
  self.coefficient.to_int()
}

///|
pub fn Decimal::round(
  self : Decimal,
  places : Int32,
) -> Decimal raise EngineError {
  let places = if places < 0 { 0 } else { places }
  if self.scale <= places {
    return self
  }
  let drop = self.scale - places
  normalize(div_half_even(self.coefficient, pow10(drop)), places)
}

///|
fn Decimal::to_double(self : Decimal) -> Double {
  let negative = self.coefficient < 0N
  let raw = (if negative { -self.coefficient } else { self.coefficient }).to_string()
  let mut value = 0.0
  for ch in raw.to_array() {
    value = value * 10.0 + (ch.to_int() - 48).to_double()
  }
  let mut divisor = 1.0
  for i = 0; i < self.scale; i = i + 1 {
    divisor = divisor * 10.0
  }
  let value = value / divisor
  if negative {
    -value
  } else {
    value
  }
}

///|
/// Build a decimal from a double rounded to `places` decimal places.
pub fn from_double(value : Double, places : Int32) -> Decimal raise EngineError {
  if value.is_nan() || value.is_inf() {
    raise fail("E_NUMBER", "non-finite number has no FEEL representation")
  }
  let mut factor = 1.0
  for i = 0; i < places; i = i + 1 {
    factor = factor * 10.0
  }
  let scaled = value * factor
  let rounded = if scaled >= 0.0 { scaled + 0.5 } else { scaled - 0.5 }
  if rounded > 9.2e18 || rounded < -9.2e18 {
    raise fail("E_NUMBER", "number outside supported exact range")
  }
  let n = rounded.to_int64()
  if places == 0 {
    return decimal_int64(n)
  }
  let text = n.to_string()
  let negative = text.has_prefix("-")
  let body = if negative {
    text.strip_prefix("-").unwrap().to_owned()
  } else {
    text
  }
  let mut padded = body
  while padded.length() <= places {
    padded = "0" + padded
  }
  let cut = padded.length() - places
  let head = String::from_array(padded.to_array()[0:cut].to_owned())
  let tail = String::from_array(padded.to_array()[cut:].to_owned())
  decimal((if negative { "-" } else { "" }) + head + "." + tail)
}

///|
pub fn Decimal::pow(a : Decimal, b : Decimal) -> Decimal raise EngineError {
  if b.scale == 0 &&
    (if b.coefficient < 0N { -b.coefficient } else { b.coefficient }).compare(
      1000N,
    ) <=
    0 {
    let n = b.coefficient.to_int()
    let mut result = decimal_int(1)
    let mut factor = a
    let mut k = if n < 0 { -n } else { n }
    while k > 0 {
      if k % 2 == 1 {
        result = result.multiply(factor)
      }
      k = k / 2
      if k > 0 {
        factor = factor.multiply(factor)
      }
    }
    if n < 0 {
      return decimal_int(1).divide(result)
    }
    return result
  }
  let value = @math.pow(a.to_double(), b.to_double())
  from_double(value, 11)
}

///|
pub fn Decimal::sqrt(self : Decimal) -> Decimal raise EngineError {
  if self.coefficient < 0N {
    raise fail("E_NUMBER", "square root of a negative number")
  }
  from_double(self.to_double().sqrt(), 12)
}

///|
pub fn Decimal::exp(self : Decimal) -> Decimal raise EngineError {
  from_double(@math.exp(self.to_double()), 8)
}

///|
pub fn Decimal::ln(self : Decimal) -> Decimal raise EngineError {
  if self.coefficient <= 0N {
    raise fail("E_NUMBER", "logarithm of a non-positive number")
  }
  from_double(@math.ln(self.to_double()), 8)
}

///|
pub fn Decimal::log10(self : Decimal) -> Decimal raise EngineError {
  if self.coefficient <= 0N {
    raise fail("E_NUMBER", "logarithm of a non-positive number")
  }
  from_double(@math.log10(self.to_double()), 8)
}

///|
pub fn Decimal::power_of_ten(n : Int32) -> Decimal {
  { coefficient: pow10(n), scale: 0, }
}

///|
pub extend Decimal with Eq::{equal, not_equal}

///|
pub extend EngineError with Eq::{equal, not_equal}
