///|
/// Exact signed decimal with at most 34 significant digits (DMN number type).
/// Division and out-of-range arithmetic are rounded half-to-even, the same
/// rounding mode required by IEEE 754 decimal128.
pub struct Decimal {
  coefficient : @bigint.BigInt
  scale : Int32
}

///|
pub impl Eq for Decimal with fn equal(self : Decimal, other : Decimal) -> Bool {
  self.compare(other) == 0
}

///|
/// Matchable engine failure carrying code, line, column and message.
#derive(Eq)
pub(all) suberror EngineError {
  Failure(String, Int32, Int32, String)
}

///|
/// Construct a semantic failure without a source location.
pub fn fail(code : String, message : String) -> EngineError {
  Failure(code, 1, 1, message)
}

///|
/// Construct a failure with a source line and column.
pub fn fail_at(
  code : String,
  line : Int32,
  column : Int32,
  message : String,
) -> EngineError {
  Failure(code, line, column, message)
}

///|
/// Extract the machine-readable error code.
pub fn error_code(e : EngineError) -> String {
  match e {
    Failure(code, _, _, _) => code
  }
}

///|
/// Extract the diagnostic message.
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
  if c.is_zero() {
    return zero()
  }
  let mut c = c
  let mut s = scale
  let drop = digit_count(c) - max_digits
  // Round once at the coarser of the precision and subnormal quantum.
  let drop = if s - 6176 > drop { s - 6176 } else { drop }
  if drop > 0 {
    c = if drop > digit_count(c) { 0N } else { div_half_even(c, pow10(drop)) }
    s = s - drop
  }
  if c.is_zero() {
    return zero()
  }
  if digit_count(c) > max_digits {
    c = c / 10N
    s = s - 1
  }
  if s < -6111 {
    let pad = -6111 - s
    if digit_count(c) + pad > max_digits {
      raise fail("E_DECIMAL_RANGE", "decimal128 overflow")
    }
    c = c * pow10(pad)
    s = -6111
  }
  while s > -6111 && (c % 10N).is_zero() {
    c = c / 10N
    s = s - 1
  }
  { coefficient: c, scale: s, }
}

///|
/// Parse a decimal literal. Accepts an optional sign, a leading dot, and a
/// decimal exponent. Values with more than 34 significant digits are rounded.
pub fn decimal(text : String) -> Decimal raise EngineError {
  let chars = text.to_array()
  if chars.is_empty() || chars.length() > 10000 {
    raise fail("E_DECIMAL_SYNTAX", "invalid decimal: " + text)
  }
  let digits = StringBuilder()
  let mut scale = 0
  let mut exp = 0
  let mut exp_sign = 1
  let mut i = 0
  let mut dot = false
  let mut exponent = false
  let mut exponent_digits = 0
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
        exponent_digits = exponent_digits + 1
        if exp > 100000 {
          raise fail("E_DECIMAL_RANGE", "decimal exponent too large")
        }
        exp = exp * 10 + (ch.to_int() - 48)
        if exp > 1000000 {
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
  if count == 0 || (exponent && exponent_digits == 0) {
    raise fail("E_DECIMAL_SYNTAX", "invalid decimal: " + text)
  }
  let coefficient = @string.parse_bigint(digits.to_string()[:]) catch {
    _ => raise fail("E_DECIMAL_SYNTAX", "invalid decimal: " + text)
  }
  normalize(coefficient, scale - exp_sign * exp)
}

///|
/// Construct an exact decimal from a 32-bit integer.
pub fn decimal_int(n : Int32) -> Decimal {
  { coefficient: @bigint.BigInt::from_int(n), scale: 0, }
}

///|
/// Construct an exact decimal from a 64-bit integer.
pub fn decimal_int64(n : Int64) -> Decimal {
  { coefficient: @bigint.BigInt::from_int64(n), scale: 0, }
}

///|
/// Construct exact decimal zero.
pub fn zero() -> Decimal {
  { coefficient: 0N, scale: 0, }
}

///|
/// Test whether the decimal coefficient is zero.
pub fn Decimal::is_zero(self : Decimal) -> Bool {
  self.coefficient.is_zero()
}

///|
/// Test the decimal sign.
pub fn Decimal::is_negative(self : Decimal) -> Bool {
  self.coefficient < 0N
}

///|
/// Test whether the normalized decimal has no fractional part.
pub fn Decimal::is_integer(self : Decimal) -> Bool {
  self.scale <= 0
}

///|
/// Format the normalized decimal without binary floating-point conversion.
pub fn Decimal::text(self : Decimal) -> String {
  if self.coefficient.is_zero() {
    return "0"
  }
  let negative = self.coefficient < 0N
  let raw = (if negative { -self.coefficient } else { self.coefficient }).to_string()
  let out = StringBuilder()
  if negative {
    out.write_char('-')
  }
  if self.scale <= 0 {
    out.write_string(raw)
    for _ in 0..<-self.scale {
      out.write_char('0')
    }
  } else {
    let cut = raw.length() - self.scale
    if cut <= 0 {
      out.write_string("0.")
      for _ in 0..<-cut {
        out.write_char('0')
      }
      out.write_string(raw)
    } else {
      // The coefficient text is ASCII, so both slices use digit boundaries.
      out.write_string(raw[:cut].to_owned())
      out.write_char('.')
      out.write_string(raw[cut:].to_owned())
    }
  }
  out.to_string()
}

///|
/// Add decimals with the engine precision limit.
pub fn Decimal::add(a : Decimal, b : Decimal) -> Decimal raise EngineError {
  let scale = if a.scale > b.scale { a.scale } else { b.scale }
  normalize(
    a.coefficient * pow10(scale - a.scale) +
    b.coefficient * pow10(scale - b.scale),
    scale,
  )
}

///|
/// Reverse the decimal sign.
pub fn Decimal::negate(a : Decimal) -> Decimal {
  { coefficient: -a.coefficient, scale: a.scale, }
}

///|
/// Return the non-negative decimal magnitude.
pub fn Decimal::abs(a : Decimal) -> Decimal {
  if a.coefficient < 0N {
    a.negate()
  } else {
    a
  }
}

///|
/// Multiply decimals with the engine precision limit.
pub fn Decimal::multiply(a : Decimal, b : Decimal) -> Decimal raise EngineError {
  normalize(a.coefficient * b.coefficient, a.scale + b.scale)
}

///|
/// Return a negative, zero or positive integer according to numeric order.
pub fn Decimal::compare(a : Decimal, b : Decimal) -> Int32 {
  if a.scale == b.scale ||
    a.is_zero() ||
    b.is_zero() ||
    a.is_negative() != b.is_negative() {
    // With the same scale, or different signs, alignment cannot change order.
    return a.coefficient.compare(b.coefficient)
  }
  if a.scale > b.scale {
    a.coefficient.compare(b.coefficient * pow10(a.scale - b.scale))
  } else {
    (a.coefficient * pow10(b.scale - a.scale)).compare(b.coefficient)
  }
}

///|
/// Divide decimals; zero divisors raise E_DIV_ZERO.
pub fn Decimal::divide(a : Decimal, b : Decimal) -> Decimal raise EngineError {
  if b.coefficient.is_zero() {
    raise fail("E_DIV_ZERO", "division by zero")
  }
  if a.is_zero() {
    return zero()
  }
  let x = if a.coefficient < 0N { -a.coefficient } else { a.coefficient }
  let y = if b.coefficient < 0N { -b.coefficient } else { b.coefficient }
  let estimate = digit_count(x) - digit_count(y)
  let below = if estimate >= 0 {
    x < y * pow10(estimate)
  } else {
    x * pow10(-estimate) < y
  }
  let adjusted = estimate - (if below { 1 } else { 0 }) + b.scale - a.scale
  let scale = 33 - adjusted
  let scale = if scale > 6176 { 6176 } else { scale }
  let shift = scale + b.scale - a.scale
  let numerator = if shift >= 0 {
    a.coefficient * pow10(shift)
  } else {
    a.coefficient
  }
  let denominator = if shift < 0 {
    b.coefficient * pow10(-shift)
  } else {
    b.coefficient
  }
  normalize(div_half_even(numerator, denominator), scale)
}

///|
/// Compute the arithmetic mean with a single rounding step, after division.
pub fn Decimal::mean(values : Array[Decimal]) -> Decimal raise EngineError {
  if values.is_empty() {
    raise fail("E_NUMBER", "mean requires a nonempty list")
  }
  // The accumulated coefficient may exceed 34 digits; division rounds
  // the quotient directly, without normalizing this total.
  exact_sum(values).divide(decimal_int(values.length()))
}

///|
/// Sum in a shared decimal quantum, rounding only after cancellation.
pub fn Decimal::sum(values : Array[Decimal]) -> Decimal raise EngineError {
  if values.is_empty() {
    return zero()
  }
  let total = exact_sum(values)
  normalize(total.coefficient, total.scale)
}

///|
fn exact_sum(values : Array[Decimal]) -> Decimal {
  let mut scale = values[0].scale
  let mut one_scale = true
  for value in values {
    if value.scale != values[0].scale {
      one_scale = false
    }
    if value.scale > scale {
      scale = value.scale
    }
  }
  let mut coefficient = 0N
  if one_scale {
    for value in values {
      coefficient += value.coefficient
    }
    return { coefficient, scale, }
  }
  let grouped : Map[Int32, @bigint.BigInt] = Map([])
  for value in values {
    grouped[value.scale] = grouped.get(value.scale).unwrap_or(0N) +
      value.coefficient
  }
  for value_scale, group in grouped {
    if !group.is_zero() {
      coefficient += if value_scale == scale {
        group
      } else {
        group * pow10(scale - value_scale)
      }
    }
  }
  { coefficient, scale, }
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
/// Compute FEEL modulo with the divisor sign convention.
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
/// Round toward negative infinity.
pub fn Decimal::floor(self : Decimal) -> Decimal raise EngineError {
  if self.scale <= 0 {
    return self
  }
  let q = floor_div(self.coefficient, pow10(self.scale))
  normalize(q, 0)
}

///|
/// Round toward positive infinity.
pub fn Decimal::ceiling(self : Decimal) -> Decimal raise EngineError {
  if self.scale <= 0 {
    return self
  }
  let q = floor_div(self.coefficient, pow10(self.scale))
  let r = self.coefficient - q * pow10(self.scale)
  normalize(if r.is_zero() { q } else { q + 1N }, 0)
}

///|
/// Discard fractional digits toward zero.
pub fn Decimal::truncate(self : Decimal) -> Decimal raise EngineError {
  if self.scale <= 0 {
    return self
  }
  normalize(self.coefficient / pow10(self.scale), 0)
}

///|
/// Convert an integral decimal to Int32; fractional values raise E_TYPE.
pub fn Decimal::to_int(self : Decimal) -> Int32 raise EngineError {
  if !self.is_integer() {
    raise fail("E_TYPE", "value is not an integer")
  }
  if self.compare(decimal_int(-2147483648)) < 0 ||
    self.compare(decimal_int(2147483647)) > 0 {
    raise fail("E_NUMBER", "integer outside Int32 range")
  }
  (self.coefficient * pow10(-self.scale)).to_int()
}

///|
/// Round half to even at the requested decimal128 scale.
pub fn Decimal::round(
  self : Decimal,
  places : Int32,
) -> Decimal raise EngineError {
  if places < -6111 || places > 6176 {
    raise fail("E_NUMBER", "rounding scale out of range")
  }
  if self.scale <= places {
    return self
  }
  let drop = self.scale - places
  normalize(div_half_even(self.coefficient, pow10(drop)), places)
}

///|
/// Quantize at a decimal place without constructing an intermediate power
/// as a Decimal, which could exceed its representable exponent range.
pub fn Decimal::directed_round(
  self : Decimal,
  places : Int32,
  mode : String,
) -> Decimal raise EngineError {
  if places < -6111 || places > 6176 {
    raise fail("E_NUMBER", "rounding scale out of range")
  }
  if self.scale <= places {
    return self
  }
  let divisor = pow10(self.scale - places)
  let magnitude = if self.coefficient < 0N {
    -self.coefficient
  } else {
    self.coefficient
  }
  let units = magnitude / divisor
  let rest = magnitude % divisor
  let increment = match mode {
    "floor" => self.coefficient < 0N && rest != 0N
    "ceiling" => self.coefficient > 0N && rest != 0N
    "round up" => rest != 0N
    "round down" => false
    "round half up" => rest * 2N >= divisor
    "round half down" => rest * 2N > divisor
    _ => raise fail("E_NUMBER", "unknown rounding mode")
  }
  let rounded = units + (if increment { 1N } else { 0N })
  normalize(if self.coefficient < 0N { -rounded } else { rounded }, places)
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
  let value = if self.scale < 0 {
    value * @math.pow(10.0, (-self.scale).to_double())
  } else {
    value / divisor
  }
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
/// Raise to a decimal power, using exact integer powers when supported.
pub fn Decimal::pow(a : Decimal, b : Decimal) -> Decimal raise EngineError {
  if b.is_integer() &&
    b.compare(decimal_int(-1000)) >= 0 &&
    b.compare(decimal_int(1000)) <= 0 &&
    (if b.coefficient < 0N { -b.coefficient } else { b.coefficient }).compare(
      1000N,
    ) <=
    0 {
    let n = b.to_int()
    if n == 0 {
      return decimal_int(1)
    }
    let k = if n < 0 { -n } else { n }
    let coefficient = a.coefficient.pow(@bigint.BigInt::from_int(k))
    let scale = a.scale * k
    if n > 0 {
      return normalize(coefficient, scale)
    }
    if coefficient != 0N && digit_count(coefficient) - 1 - scale > 6176 {
      // The reciprocal lies below half the smallest subnormal.
      return zero()
    }
    let exact : Decimal = { coefficient, scale, }
    return decimal_int(1).divide(exact)
  }
  let value = @math.pow(a.to_double(), b.to_double())
  from_double(value, 11)
}

///|
/// Compute the correctly rounded 34-digit square root with integer Newton steps.
pub fn Decimal::sqrt(self : Decimal) -> Decimal raise EngineError {
  if self.coefficient < 0N {
    raise fail("E_NUMBER", "square root of a negative number")
  }
  if self.is_zero() {
    return zero()
  }
  // Scale the radicand to 67 or 68 digits, leaving exactly 34 root digits.
  let shift = 2 * max_digits - digit_count(self.coefficient)
  let shift = if (self.scale + shift) % 2 == 0 { shift } else { shift - 1 }
  let radicand = self.coefficient * pow10(shift)
  let mut root = pow10(max_digits)
  while true {
    let next = (root + radicand / root) / 2N
    if next >= root {
      break
    }
    root = next
  }
  // (root + 1/2)^2 = root^2 + root + 1/4: no integral radicand ties.
  let rounded = if radicand - root * root > root { root + 1N } else { root }
  normalize(rounded, (self.scale + shift) / 2)
}

///|
/// Exact sample variance in a shared decimal quantum, then round its root once.
pub fn Decimal::sample_deviation(
  values : Array[Decimal],
) -> Decimal raise EngineError {
  if values.length() < 2 {
    raise fail("E_NUMBER", "sample deviation requires at least two values")
  }
  let mut scale = values[0].scale
  for value in values {
    if value.scale > scale {
      scale = value.scale
    }
  }
  let mut total = 0N
  let mut squares = 0N
  for value in values {
    let v = value.coefficient * pow10(scale - value.scale)
    total = total + v
    squares = squares + v * v
  }
  let count = @bigint.BigInt::from_int(values.length())
  let a = count * squares - total * total
  if a == 0N {
    return zero()
  }
  let b = count * (count - 1N)
  // Determine floor(log10(a/b)) by comparing integers, including small quotients.
  let e = digit_count(a) - digit_count(b)
  let below = if e >= 0 { a < b * pow10(e) } else { a * pow10(-e) < b }
  let e = e - (if below { 1 } else { 0 })
  let half = (if e < 0 { e - 1 } else { e }) / 2
  let target = 33 - half + scale
  let target = if target > 6176 { 6176 } else { target }
  let shift = 2 * (target - scale)
  let num = if shift > 0 { a * pow10(shift) } else { a }
  let den = if shift < 0 { b * pow10(-shift) } else { b }
  let whole = num / den
  let mut root = pow10(34)
  if whole == 0N {
    root = 0N
  } else {
    while true {
      let next = (root + whole / root) / 2N
      if next >= root {
        break
      }
      root = next
    }
  }
  let midpoint = 2N * root + 1N
  let cmp = (4N * num).compare(den * midpoint * midpoint)
  let rounded = if cmp > 0 || (cmp == 0 && root % 2N != 0N) {
    root + 1N
  } else {
    root
  }
  normalize(rounded, target)
}

///|
/// Compute the exponential through the floating-point bridge.
pub fn Decimal::exp(self : Decimal) -> Decimal raise EngineError {
  from_double(@math.exp(self.to_double()), 8)
}

///|
/// Compute the natural logarithm through the floating-point bridge.
pub fn Decimal::ln(self : Decimal) -> Decimal raise EngineError {
  if self.coefficient <= 0N {
    raise fail("E_NUMBER", "logarithm of a non-positive number")
  }
  let ordinary = self.to_double()
  if ordinary != 0.0 && !ordinary.is_inf() {
    return from_double(@math.ln(ordinary), 8)
  }
  // For values lost to the binary64 exponent range, split the decimal
  // magnitude; the coefficient has at most 34 digits.
  let coefficient : Decimal = { coefficient: self.coefficient, scale: 0, }
  from_double(
    @math.ln(coefficient.to_double()) - self.scale.to_double() * @math.ln(10.0),
    8,
  )
}

///|
/// Compute the base-ten logarithm through the floating-point bridge.
pub fn Decimal::log10(self : Decimal) -> Decimal raise EngineError {
  if self.coefficient <= 0N {
    raise fail("E_NUMBER", "logarithm of a non-positive number")
  }
  // The coefficient has at most 34 digits even when the value is outside binary64.
  let coefficient : Decimal = { coefficient: self.coefficient, scale: 0 }
  from_double(@math.log10(coefficient.to_double()) - self.scale.to_double(), 8)
}

///|
/// Construct a decimal power of ten.
pub fn Decimal::power_of_ten(n : Int32) -> Decimal raise EngineError {
  if n < -6176 || n > 6144 {
    raise fail("E_DECIMAL_RANGE", "power outside decimal128 range")
  }
  normalize(1N, -n)
}

///|
pub extend Decimal with Eq::{equal, not_equal}

///|
pub extend EngineError with Eq::{equal, not_equal}

///|
/// Human-readable structured diagnostic for callers catching EngineError.
pub fn EngineError::to_string(self : EngineError) -> String {
  match self {
    Failure(code, line, column, message) =>
      code +
      " at " +
      line.to_string() +
      ":" +
      column.to_string() +
      ": " +
      message
  }
}
