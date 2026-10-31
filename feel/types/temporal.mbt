///|
/// Calendar date in the proleptic Gregorian calendar (years 1..9999).
pub(all) struct Date {
  year : Int32
  month : Int32
  day : Int32
}

///|
/// Time of day with optional UTC offset or named IANA zone.
pub(all) struct Time {
  hour : Int32
  minute : Int32
  second : Int32
  nanos : Int32
  zone : Zone
}

///|
/// Unzoned, fixed-offset or named time zone representation.
pub(all) enum Zone {
  Unzoned
  Fixed(Int32) // offset in seconds east of UTC
  Named(String)
}

///|
/// Calendar date and local time with an optional zone.
pub(all) struct DateTime {
  date : Date
  time : Time
}

///|
/// Days and time duration. `days` plus `nanos` (always less than one day),
/// with a separate sign so that the canonical form is unique.
pub(all) struct DurationDS {
  negative : Bool
  days : Int64
  nanos : Int64
}

///|
/// Years and months duration, canonicalised so 0 <= months < 12.
pub(all) struct DurationYM {
  negative : Bool
  years : Int32
  months : Int32
}

///|
/// Test the Gregorian leap-year rule.
pub fn is_leap_year(year : Int32) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
/// Return the month length, or zero for an invalid month.
pub fn days_in_month(year : Int32, month : Int32) -> Int32 {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
}

///|
/// Convert a Gregorian date to signed days since 1970-01-01.
pub fn days_from_civil(year : Int32, month : Int32, day : Int32) -> Int64 {
  let y = if month <= 2 { year - 1 } else { year }
  let era = (if y >= 0 { y } else { y - 399 }) / 400
  let yoe = y - era * 400
  let mp = if month > 2 { month - 3 } else { month + 9 }
  let doy = (153 * mp + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  (era * 146097 + doe - 719468).to_int64()
}

///|
/// Convert signed days since 1970-01-01 to a Gregorian date.
pub fn civil_from_days(days : Int64) -> Date {
  let z = days + 719468L
  let era = (if z >= 0L { z } else { z - 146096L }) / 146097L
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = if mp < 10L { mp + 3L } else { mp - 9L }
  {
    year: (if m <= 2L { y + 1L } else { y }).to_int(),
    month: m.to_int(),
    day: d.to_int(),
  }
}

///|
/// Return signed days since 1970-01-01.
pub fn Date::ordinal(self : Date) -> Int64 {
  days_from_civil(self.year, self.month, self.day)
}

///|
/// Return the ISO weekday, Monday=1 through Sunday=7.
pub fn Date::weekday(self : Date) -> Int32 {
  let w = (self.ordinal() + 3L) % 7L
  w.to_int() + 1
}

///|
/// Return the one-based day within the year.
pub fn Date::day_of_year(self : Date) -> Int32 {
  (self.ordinal() - days_from_civil(self.year, 1, 1) + 1L).to_int()
}

///|
fn weeks_in_year(year : Int32) -> Int32 {
  let jan1 = Date::{ year, month: 1, day: 1, }
  let wd = jan1.weekday()
  if wd == 4 || (is_leap_year(year) && wd == 3) {
    53
  } else {
    52
  }
}

///|
/// Return the ISO week number, including adjacent-year weeks.
pub fn Date::week_of_year(self : Date) -> Int32 {
  let ordinal = self.day_of_year()
  let weekday = self.weekday()
  let mut week = (ordinal - weekday + 10) / 7
  if week < 1 {
    week = weeks_in_year(self.year - 1)
  } else if week > weeks_in_year(self.year) {
    week = 1
  }
  week
}

///|
/// Format the calendar date as an ISO date.
pub fn Date::text(self : Date) -> String {
  let month = (if self.month < 10 { "0" } else { "" }) + self.month.to_string()
  let day = (if self.day < 10 { "0" } else { "" }) + self.day.to_string()
  let magnitude = if self.year < 0 { -self.year } else { self.year }
  let mut year = magnitude.to_string()
  while year.length() < 4 {
    year = "0" + year
  }
  let year = if self.year < 0 { "-" + year } else { year }
  year + "-" + month + "-" + day
}

///|
/// Validate year, month and day and construct a Gregorian date.
pub fn date_of(
  year : Int32,
  month : Int32,
  day : Int32,
) -> Date raise EngineError {
  if year < -999999999 || year > 999999999 {
    raise fail("E_DATE_RANGE", "year outside supported range")
  }
  if month < 1 || month > 12 {
    raise fail("E_DATE_INVALID", "month outside 1..12")
  }
  if day < 1 || day > days_in_month(year, month) {
    raise fail("E_DATE_INVALID", "day outside month range")
  }
  { year, month, day, }
}

///|
fn parse_uint(text : String) -> Int32 raise EngineError {
  if text == "" || text.length() > 9 {
    raise fail("E_PARSE", "invalid integer")
  }
  let mut n = 0
  for ch in text.to_array() {
    if ch < '0' || ch > '9' {
      raise fail("E_PARSE", "invalid integer")
    }
    n = n * 10 + (ch.to_int() - 48)
  }
  n
}

///|
fn two_digits(s : String, at : Int32, what : String) -> Int32 raise EngineError {
  if at + 2 > s.length() {
    raise fail("E_PARSE", "incomplete " + what)
  }
  let slice = String::from_array(s.to_array()[at:at + 2].to_owned())
  for ch in slice.to_array() {
    if ch < '0' || ch > '9' {
      raise fail("E_PARSE", "invalid " + what)
    }
  }
  parse_uint(slice)
}

///|
/// Parse an ISO date, rejecting invalid calendar components.
pub fn parse_date(text : String) -> Date raise EngineError {
  let s = text.trim().to_owned()
  let chars = s.to_array()
  let len = chars.length()
  let mut start = 0
  let mut negative = false
  if len > 0 && chars[0] == '-' {
    negative = true
    start = 1
  }
  if len < 10 || chars[len - 3] != '-' || chars[len - 6] != '-' {
    raise fail("E_DATE_INVALID", "invalid date: " + s)
  }
  if len - 6 - start < 4 {
    raise fail("E_DATE_INVALID", "invalid year: " + s)
  }
  let year = String::from_array(chars[start:len - 6].to_owned())
  for ch in year.to_array() {
    if ch < '0' || ch > '9' {
      raise fail("E_DATE_INVALID", "invalid year: " + s)
    }
  }
  let y = parse_uint(year)
  let year = if negative { -y } else { y }
  date_of(year, two_digits(s, len - 5, "month"), two_digits(s, len - 2, "day"))
}

///|
fn parse_fraction(
  text : String,
  start : Int32,
) -> (Int32, Int32) raise EngineError {
  let out = StringBuilder()
  let mut i = start
  let chars = text.to_array()
  while i < chars.length() && chars[i] >= '0' && chars[i] <= '9' {
    out.write_char(chars[i])
    i = i + 1
  }
  let digits = out.to_string()
  if digits.length() > 9 {
    raise fail("E_TIME_INVALID", "more than nanosecond precision")
  }
  let mut nanos = if digits == "" { 0 } else { parse_uint(digits) }
  let mut k = digits.length()
  while k < 9 {
    nanos = nanos * 10
    k = k + 1
  }
  (nanos, i)
}

///|
fn parse_offset(
  text : String,
  start : Int32,
) -> (Zone, Int32) raise EngineError {
  let chars = text.to_array()
  if start >= chars.length() {
    return (Unzoned, start)
  }
  if chars[start] == 'Z' {
    return (Fixed(0), start + 1)
  }
  if chars[start] == '@' {
    let name = String::from_array(chars[start + 1:].to_owned())
    if name == "" {
      raise fail("E_TIME_INVALID", "empty time zone")
    }
    return (Named(name), chars.length())
  }
  if chars[start] != '+' && chars[start] != '-' {
    return (Unzoned, start)
  }
  let sign = if chars[start] == '-' { -1 } else { 1 }
  if start + 6 > chars.length() || chars[start + 3] != ':' {
    raise fail("E_TIME_INVALID", "invalid UTC offset")
  }
  let hours = two_digits(text, start + 1, "offset hour")
  let minutes = two_digits(text, start + 4, "offset minute")
  if hours > 14 || minutes > 59 || (hours == 14 && minutes != 0) {
    raise fail("E_TIME_INVALID", "UTC offset out of range")
  }
  (Fixed(sign * (hours * 3600 + minutes * 60)), start + 6)
}

///|
/// Parse an ISO time with an optional UTC offset or named zone.
pub fn parse_time(text : String) -> Time raise EngineError {
  let s = text.trim().to_owned()
  let chars = s.to_array()
  if chars.length() < 8 || chars[2] != ':' || chars[5] != ':' {
    raise fail("E_TIME_INVALID", "invalid time: " + s)
  }
  let hour = two_digits(s, 0, "hour")
  let minute = two_digits(s, 3, "minute")
  let second = two_digits(s, 6, "second")
  let mut at = 8
  let nanos = if at < chars.length() && chars[at] == '.' {
    let (n, next) = parse_fraction(s, at + 1)
    if next == at + 1 {
      raise fail("E_TIME_INVALID", "empty fraction")
    }
    at = next
    n
  } else {
    0
  }
  let (zone, end) = parse_offset(s, at)
  if end != chars.length() {
    raise fail("E_TIME_INVALID", "trailing characters in time: " + s)
  }
  if minute > 59 ||
    second > 59 ||
    hour > 24 ||
    (hour == 24 && (minute != 0 || second != 0 || nanos != 0)) {
    raise fail("E_TIME_INVALID", "time component out of range")
  }
  if zone is Named(name) && zone_transitions(name) is None {
    raise fail("E_ZONE_UNSUPPORTED", "unknown time zone: " + name)
  }
  { hour, minute, second, nanos, zone, }
}

///|
/// Validate and construct a time from integer components.
pub fn make_time(
  hour : Int32,
  minute : Int32,
  second : Int32,
  nanos : Int32,
  zone : Zone,
) -> Time raise EngineError {
  if hour < 0 ||
    hour > 24 ||
    minute < 0 ||
    minute > 59 ||
    second < 0 ||
    second > 59 ||
    nanos < 0 ||
    nanos > 999999999 ||
    (hour == 24 && (minute != 0 || second != 0 || nanos != 0)) {
    raise fail("E_TIME_INVALID", "time component out of range")
  }
  { hour, minute, second, nanos, zone, }
}

///|
/// Parse a UTC offset beginning at `start`.
pub fn parse_offset_text(
  text : String,
  start : Int32,
) -> (Zone, Int32) raise EngineError {
  parse_offset(text, start)
}

///|
/// Format time, fractional seconds and the stored zone.
pub fn Time::text(self : Time) -> String {
  let hour = (if self.hour < 10 { "0" } else { "" }) + self.hour.to_string()
  let minute = (if self.minute < 10 { "0" } else { "" }) +
    self.minute.to_string()
  let second = (if self.second < 10 { "0" } else { "" }) +
    self.second.to_string()
  let mut out = hour + ":" + minute + ":" + second
  if self.nanos != 0 {
    let mut raw = self.nanos.to_string()
    while raw.length() < 9 {
      raw = "0" + raw
    }
    while raw.has_suffix("0") {
      raw = raw.strip_suffix("0").unwrap().to_owned()
    }
    out = out + "." + raw
  }
  match self.zone {
    Unzoned => out
    Fixed(0) => out + "Z"
    Fixed(offset) => {
      let sign = if offset < 0 { "-" } else { "+" }
      let a = if offset < 0 { -offset } else { offset }
      let h = a / 3600
      let m = a % 3600 / 60
      out +
      sign +
      (if h < 10 { "0" } else { "" }) +
      h.to_string() +
      ":" +
      (if m < 10 { "0" } else { "" }) +
      m.to_string()
    }
    Named(name) => out + "@" + name
  }
}

///|
/// Parse an ISO date and time separated by T.
pub fn parse_datetime(text : String) -> DateTime raise EngineError {
  let s = text.trim().to_owned()
  let idx = s.find("T")
  let index = match idx {
    Some(i) => i
    None => raise fail("E_DATETIME_INVALID", "missing T separator")
  }
  let date_part = String::from_array(s.to_array()[0:index].to_owned())
  let time_part = String::from_array(s.to_array()[index + 1:].to_owned())
  datetime_of(parse_date(date_part), parse_time(time_part))
}

///|
/// Format the stored date, time and zone as ISO text.
pub fn DateTime::text(self : DateTime) -> String {
  self.date.text() + "T" + self.time.text()
}

///|
/// Seconds since midnight, ignoring the zone.
pub fn Time::seconds(self : Time) -> Int64 {
  (self.hour * 3600 + self.minute * 60 + self.second).to_int64() * 1000000000L +
  self.nanos.to_int64()
}

///|
/// Absolute instant as nanoseconds since 1970-01-01T00:00:00Z.
/// Fails when the value has no resolvable offset.
pub fn DateTime::instant(self : DateTime) -> Int64 raise EngineError {
  if self.time.zone is Unzoned {
    raise fail(
      "E_ZONE_UNSUPPORTED", "date and time without offset has no instant",
    )
  }
  let offset = datetime_zone_offset(self)
  let days = self.date.ordinal()
  (days * 86400L + self.time.seconds() / 1000000000L - offset.to_int64()) *
  1000000000L +
  self.time.seconds() % 1000000000L
}

///|
/// Test whether this date-time carries a fixed or named zone.
pub fn DateTime::has_offset(self : DateTime) -> Bool {
  match self.time.zone {
    Fixed(_) => true
    Named(_) => true
    Unzoned => false
  }
}

///|
/// Resolve an IANA offset at a complete local time using embedded 2026e data.
/// Gaps fail explicitly; overlaps choose the earlier UTC instant.
pub fn datetime_zone_offset(value : DateTime) -> Int32 raise EngineError {
  match value.time.zone {
    Unzoned => 0
    Fixed(offset) => offset
    Named(name) => {
      let entries = match zone_transitions(name) {
        Some(entries) => entries
        None => raise fail("E_ZONE_UNSUPPORTED", "unknown time zone: " + name)
      }
      if value.date.year < 1970 || value.date.year > 2100 {
        raise fail("E_ZONE_RANGE", "IANA data covers 1970 through 2100")
      }
      let local_seconds = value.date.ordinal() * 86400L +
        value.time.seconds() / 1000000000L
      let mut chosen : Int32? = None
      let mut earliest = 9223372036854775807L
      for i, entry in entries {
        let until = if i + 1 < entries.length() {
          entries[i + 1].0
        } else {
          4133980800L
        }
        let utc = local_seconds - entry.1.to_int64()
        if utc >= entry.0 && utc < until && utc < earliest {
          chosen = Some(entry.1)
          earliest = utc
        }
      }
      match chosen {
        Some(offset) => offset
        None =>
          raise fail(
            "E_ZONE_GAP", "local time is nonexistent or outside embedded UTC coverage",
          )
      }
    }
  }
}

///|
/// Compatibility helper: resolve at local midnight, never guess a whole-day offset.
pub fn named_zone_offset(name : String, date : Date) -> Int32? {
  Some(
    datetime_zone_offset({
      date,
      time: { hour: 0, minute: 0, second: 0, nanos: 0, zone: Named(name), },
    }),
  ) catch {
    _ => None
  }
}

///|
/// Compatibility helper for local midnight. Use datetime_zone_offset for a time.
pub fn zone_offset_seconds(zone : Zone, date : Date) -> Int32 raise EngineError {
  datetime_zone_offset({
    date,
    time: { hour: 0, minute: 0, second: 0, nanos: 0, zone, },
  })
}

///|
/// Only date-independent named offsets can resolve a time without a date.
pub fn standard_zone_offset(zone : Zone) -> Int32? {
  match zone {
    Unzoned => Some(0)
    Fixed(offset) => Some(offset)
    Named(name) =>
      match zone_transitions(name) {
        Some(entries) if entries.iter().all(e => e.1 == entries[0].1) =>
          Some(entries[0].1)
        _ => None
      }
  }
}

///|
/// Add signed calendar days without changing the calendar representation.
pub fn date_add_days(date : Date, days : Int64) -> Date {
  civil_from_days(date.ordinal() + days)
}

///|
/// Add signed months, clamping the day to the destination month.
pub fn date_add_months(date : Date, months : Int32) -> Date raise EngineError {
  let total = date.year * 12 + (date.month - 1) + months
  let year = if total >= 0 { total / 12 } else { (total - 11) / 12 }
  let month = total - year * 12 + 1
  let day = if date.day > days_in_month(year, month) {
    days_in_month(year, month)
  } else {
    date.day
  }
  date_of(year, month, day)
}

///|
/// Normalize signed day and nanosecond components.
pub fn DurationDS::canonical(
  negative : Bool,
  days : Int64,
  nanos : Int64,
) -> DurationDS {
  let day_nanos = 86400000000000L
  let extra = nanos / day_nanos
  let rest = nanos % day_nanos
  let days = days + extra
  let zero = days == 0L && rest == 0L
  { negative: if zero { false } else { negative }, days, nanos: rest, }
}

///|
/// Construct a zero days-and-time duration.
pub fn DurationDS::zero() -> DurationDS {
  { negative: false, days: 0L, nanos: 0L, }
}

///|
/// Test whether both duration components are zero.
pub fn DurationDS::is_zero(self : DurationDS) -> Bool {
  self.days == 0L && self.nanos == 0L
}

///|
/// Return the exact signed nanosecond count as a BigInt.
pub fn DurationDS::total_nanos(self : DurationDS) -> @bigint.BigInt {
  let n = @bigint.BigInt::from_int64(self.days) * 86400000000000N +
    @bigint.BigInt::from_int64(self.nanos)
  if self.negative {
    -n
  } else {
    n
  }
}

///|
/// Reverse the duration sign while preserving canonical zero.
pub fn DurationDS::negate(self : DurationDS) -> DurationDS {
  DurationDS::canonical(!self.negative, self.days, self.nanos)
}

///|
/// Add two exact days-and-time durations.
pub fn DurationDS::add(a : DurationDS, b : DurationDS) -> DurationDS {
  let total = a.total_nanos() + b.total_nanos()
  duration_ds_of_nanos(total)
}

///|
/// Subtract two exact days-and-time durations.
pub fn DurationDS::subtract(a : DurationDS, b : DurationDS) -> DurationDS {
  a.add(b.negate())
}

///|
/// Build a canonical duration from a signed nanosecond count, rounding
/// sub-nanosecond input is not possible by construction.
pub fn duration_ds_of_nanos(total : @bigint.BigInt) -> DurationDS {
  let negative = total < 0N
  let a = if negative { -total } else { total }
  let day_nanos = @bigint.BigInt::from_int64(86400000000000L)
  let days = a / day_nanos
  let nanos = a % day_nanos
  {
    negative: if a.is_zero() {
      false
    } else {
      negative
    },
    days: days.to_int64(),
    nanos: nanos.to_int64(),
  }
}

///|
/// Format a canonical ISO days-and-time duration.
pub fn DurationDS::text(self : DurationDS) -> String {
  if self.is_zero() {
    return "P0D"
  }
  let out = StringBuilder()
  if self.negative {
    out.write_char('-')
  }
  out.write_char('P')
  if self.days > 0L {
    out.write_string(self.days.to_string())
    out.write_char('D')
  }
  if self.nanos > 0L {
    let total = self.nanos
    let hours = total / 3600000000000L
    let rem = total % 3600000000000L
    let minutes = rem / 60000000000L
    let rem = rem % 60000000000L
    let seconds = rem / 1000000000L
    let nanos = rem % 1000000000L
    out.write_char('T')
    if hours > 0L {
      out.write_string(hours.to_string())
      out.write_char('H')
    }
    if minutes > 0L {
      out.write_string(minutes.to_string())
      out.write_char('M')
    }
    if seconds > 0L || nanos > 0L {
      let mut sec = seconds.to_string()
      if nanos > 0L {
        let mut frac = nanos.to_string()
        while frac.length() < 9 {
          frac = "0" + frac
        }
        while frac.has_suffix("0") {
          frac = frac.strip_suffix("0").unwrap().to_owned()
        }
        sec = sec + "." + frac
      }
      out.write_string(sec)
      out.write_char('S')
    }
  }
  out.to_string()
}

///|
/// Normalize years and months with a separate sign.
pub fn DurationYM::canonical(
  negative : Bool,
  years : Int32,
  months : Int32,
) -> DurationYM {
  let total = years * 12 + months
  let y = total / 12
  let m = total % 12
  { negative: if total == 0 { false } else { negative }, years: y, months: m, }
}

///|
/// Construct a zero years-and-months duration.
pub fn DurationYM::zero() -> DurationYM {
  { negative: false, years: 0, months: 0, }
}

///|
/// Test whether the years-and-months duration is zero.
pub fn DurationYM::is_zero(self : DurationYM) -> Bool {
  self.years == 0 && self.months == 0
}

///|
/// Return the signed total number of months.
pub fn DurationYM::total_months(self : DurationYM) -> Int32 {
  let n = self.years * 12 + self.months
  if self.negative {
    -n
  } else {
    n
  }
}

///|
/// Format a canonical ISO years-and-months duration.
pub fn DurationYM::text(self : DurationYM) -> String {
  if self.is_zero() {
    return "P0M"
  }
  let out = StringBuilder()
  if self.negative {
    out.write_char('-')
  }
  out.write_char('P')
  if self.years != 0 {
    out.write_string(self.years.to_string())
    out.write_char('Y')
  }
  if self.months != 0 {
    out.write_string(self.months.to_string())
    out.write_char('M')
  }
  out.to_string()
}

///|
/// Convert a decimal component to an integer in `target_scale` units,
/// rounding half-to-even.
pub fn decimal_to_scaled(d : Decimal, target_scale : Int32) -> @bigint.BigInt {
  if d.scale <= target_scale {
    d.coefficient *
    @bigint.BigInt::from_int(10).pow(
      @bigint.BigInt::from_int(target_scale - d.scale),
    )
  } else {
    let drop = d.scale - target_scale
    let divisor = @bigint.BigInt::from_int(10).pow(
      @bigint.BigInt::from_int(drop),
    )
    let a = if d.coefficient < 0N { -d.coefficient } else { d.coefficient }
    let q = a / divisor
    let r = a % divisor
    let twice = r * 2N
    let rounded = if twice > divisor {
      q + 1N
    } else if twice < divisor {
      q
    } else if (q % 2N).is_zero() {
      q
    } else {
      q + 1N
    }
    if d.coefficient < 0N {
      -rounded
    } else {
      rounded
    }
  }
}

///|
/// Parse an ISO 8601 duration. Durations mixing date and time-of-day
/// components with years/months are rejected, as required by FEEL.
pub fn parse_duration(
  text : String,
) -> (DurationDS, DurationYM) raise EngineError {
  let s = text.trim().to_owned()
  let chars = s.to_array()
  if chars.length() < 2 {
    raise fail("E_DURATION_INVALID", "invalid duration: " + s)
  }
  let mut i = 0
  let mut negative = false
  if chars[0] == '-' {
    negative = true
    i = 1
  } else if chars[0] == '+' {
    i = 1
  }
  if i >= chars.length() || chars[i] != 'P' {
    raise fail("E_DURATION_INVALID", "invalid duration: " + s)
  }
  i = i + 1
  let mut total_nanos = 0N
  let mut total_months = 0N
  let mut in_time = false
  let mut has_ds = false
  let mut has_ym = false
  let mut seen = false
  while i < chars.length() {
    if chars[i] == 'T' {
      in_time = true
      i = i + 1
      if i >= chars.length() {
        raise fail("E_DURATION_INVALID", "trailing T in duration")
      }
      continue
    }
    let start = i
    let digits = StringBuilder()
    while i < chars.length() &&
          (
            (chars[i] >= '0' && chars[i] <= '9') ||
            chars[i] == '.' ||
            chars[i] == ','
          ) {
      digits.write_char(if chars[i] == ',' { '.' } else { chars[i] })
      i = i + 1
    }
    if i >= chars.length() || i == start {
      raise fail("E_DURATION_INVALID", "missing duration component")
    }
    let unit = chars[i]
    i = i + 1
    let value = decimal(digits.to_string())
    let n = decimal_to_scaled(value, 9)
    let integral = match unit {
      'Y' | 'M' => decimal_to_scaled(value, 0)
      _ => n
    }
    seen = true
    match unit {
      'Y' => {
        if in_time {
          raise fail("E_DURATION_INVALID", "years not allowed after T")
        }
        has_ym = true
        total_months = total_months + integral * 12N
      }
      'M' =>
        if in_time {
          has_ds = true
          total_nanos = total_nanos + n * 60N
        } else {
          has_ym = true
          total_months = total_months + integral
        }
      'W' => {
        if in_time {
          raise fail("E_DURATION_INVALID", "weeks not allowed after T")
        }
        has_ds = true
        total_nanos = total_nanos + n * 604800N
      }
      'D' => {
        if in_time {
          raise fail("E_DURATION_INVALID", "days not allowed after T")
        }
        has_ds = true
        total_nanos = total_nanos + n * 86400N
      }
      'H' => {
        if !in_time {
          raise fail("E_DURATION_INVALID", "hours require T")
        }
        has_ds = true
        total_nanos = total_nanos + n * 3600N
      }
      'S' => {
        if !in_time {
          raise fail("E_DURATION_INVALID", "seconds require T")
        }
        has_ds = true
        total_nanos = total_nanos + n
      }
      _ =>
        raise fail(
          "E_DURATION_INVALID",
          "unknown duration unit: " + unit.to_string(),
        )
    }
  }
  if !seen {
    raise fail("E_DURATION_INVALID", "empty duration")
  }
  if has_ds && has_ym {
    raise fail(
      "E_DURATION_INVALID", "cannot mix years/months with days/time components",
    )
  }
  if has_ym {
    let total = total_months
    let years = (if total < 0N { -total } else { total }).to_int() / 12
    let months = (if total < 0N { -total } else { total }).to_int() % 12
    (
      DurationDS::zero(),
      DurationYM::canonical(negative && !total.is_zero(), years, months),
    )
  } else {
    (
      duration_ds_of_nanos(if negative { -total_nanos } else { total_nanos }),
      DurationYM::zero(),
    )
  }
}

///|
/// Convert an exact UTC instant to a local date-time in the embedded IANA range.
pub fn datetime_from_instant(
  nanos : @bigint.BigInt,
  zone : Zone,
) -> DateTime raise EngineError {
  if nanos < 0N || nanos >= 4133980800000000000N {
    raise fail("E_ZONE_RANGE", "instant outside embedded IANA coverage")
  }
  let seconds = (nanos / 1000000000N).to_int64()
  let offset = match zone {
    Named(name) => {
      let entries = match zone_transitions(name) {
        Some(entries) => entries
        None => raise fail("E_ZONE_UNSUPPORTED", "unknown time zone: " + name)
      }
      let mut offset = entries[0].1
      for entry in entries {
        if entry.0 > seconds {
          break
        }
        offset = entry.1
      }
      offset
    }
    Fixed(offset) => offset
    Unzoned => 0
  }
  let shifted = seconds + offset.to_int64()
  let day = if shifted < 0L {
    (shifted - 86399L) / 86400L
  } else {
    shifted / 86400L
  }
  let within = shifted - day * 86400L
  let date = civil_from_days(day)
  if date.year < 1970 || date.year > 2100 {
    raise fail("E_ZONE_RANGE", "local date outside embedded IANA coverage")
  }
  {
    date,
    time: {
      hour: (within / 3600L).to_int(),
      minute: (within % 3600L / 60L).to_int(),
      second: (within % 60L).to_int(),
      nanos: (nanos % 1000000000N).to_int(),
      zone,
    },
  }
}

///|
/// Construct a local date-time and reject nonexistent times in covered IANA years.
pub fn datetime_of(date : Date, time : Time) -> DateTime raise EngineError {
  let value : DateTime = { date, time, }
  if time.zone is Named(name) {
    if zone_transitions(name) is None {
      raise fail("E_ZONE_UNSUPPORTED", "unknown time zone: " + name)
    }
    if date.year >= 1970 && date.year <= 2100 {
      ignore(datetime_zone_offset(value))
    }
  }
  value
}
