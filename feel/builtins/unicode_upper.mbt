///|
/// Locale-independent Unicode uppercase. SpecialCasing expansions precede simple mappings.
fn full_upper(input : String) -> String {
  if input.iter().all(ch => ch.to_int() < 128) {
    return input.to_upper()
  }
  let out = StringBuilder()
  for ch in input.iter() {
    let cp = ch.to_int()
    if upper_expansions.get(cp) is Some(s) {
      out.write_string(s)
      continue
    }
    let mut low = 0
    let mut high = upper_ranges.length()
    while low < high {
      let mid = (low + high) / 2
      if upper_ranges[mid].1 < cp {
        low = mid + 1
      } else {
        high = mid
      }
    }
    if low < upper_ranges.length() && upper_ranges[low].0 <= cp {
      out.write_char((cp + upper_ranges[low].2).unsafe_to_char())
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}
