///|
/// Locale-independent Unicode uppercase. SpecialCasing expansions precede simple mappings.
fn full_upper(input : String) -> String {
  if input.iter().all(ch => ch.to_int() < 128) {
    return input.to_upper()
  }
  map_case(input, upper_ranges, upper_expansions)
}

///|
/// Apply unconditional lower mappings without relying on a backend's Unicode version.
fn standard_lower(input : String) -> String {
  if input.iter().all(ch => ch.to_int() < 128) {
    return input.to_lower()
  }
  map_case(input, lower_ranges, lower_expansions)
}

///|
fn map_case(
  input : String,
  ranges : Array[(Int32, Int32, Int32)],
  expansions : Map[Int32, String],
) -> String {
  let out = StringBuilder()
  for ch in input.iter() {
    let cp = ch.to_int()
    if expansions.get(cp) is Some(s) {
      out.write_string(s)
      continue
    }
    let mut low = 0
    let mut high = ranges.length()
    while low < high {
      let mid = (low + high) / 2
      if ranges[mid].1 < cp {
        low = mid + 1
      } else {
        high = mid
      }
    }
    if low < ranges.length() && ranges[low].0 <= cp {
      out.write_char((cp + ranges[low].2).unsafe_to_char())
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}
