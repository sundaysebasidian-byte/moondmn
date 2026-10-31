///|
/// FEEL interval. Missing endpoints are unbounded.
pub(all) struct Range {
  start : Value?
  start_included : Bool
  end : Value?
  end_included : Bool
}

///|
pub fn Range::unbounded() -> Range {
  { start: None, start_included: false, end: None, end_included: false, }
}

///|
pub fn Range::contains(range : Range, value : Value) -> Bool raise EngineError {
  if value is Null {
    return false
  }
  if range.start is Some(low) {
    let c = compare_values(value, low)
    if c < 0 || (c == 0 && !range.start_included) {
      return false
    }
  }
  if range.end is Some(high) {
    let c = compare_values(value, high)
    if c > 0 || (c == 0 && !range.end_included) {
      return false
    }
  }
  true
}

///|
pub fn Range::overlaps(a : Range, b : Range) -> Bool raise EngineError {
  let starts_before_end_of_b = match a.start {
    None => true
    Some(x) =>
      match b.end {
        None => true
        Some(y) => {
          let c = compare_values(x, y)
          c < 0 || (c == 0 && a.start_included && b.end_included)
        }
      }
  }
  let starts_before_end_of_a = match b.start {
    None => true
    Some(x) =>
      match a.end {
        None => true
        Some(y) => {
          let c = compare_values(x, y)
          c < 0 || (c == 0 && b.start_included && a.end_included)
        }
      }
  }
  starts_before_end_of_b && starts_before_end_of_a
}

///|
pub fn Range::text(range : Range) -> String {
  let low = match range.start {
    Some(v) => v.text()
    None => ""
  }
  let high = match range.end {
    Some(v) => v.text()
    None => ""
  }
  let left = if range.start_included { "[" } else { "(" }
  let right = if range.end_included { "]" } else { ")" }
  left + low + ".." + high + right
}

///|
pub fn Range::json(range : Range) -> Json raise EngineError {
  let start = match range.start {
    Some(v) => v.json()
    None => Json::null()
  }
  let end = match range.end {
    Some(v) => v.json()
    None => Json::null()
  }
  Json::object(
    Map([
      ("start", start),
      ("startIncluded", Json(range.start_included)),
      ("end", end),
      ("endIncluded", Json(range.end_included)),
    ]),
  )
}
