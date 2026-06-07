/// Parses a user-entered decimal that may use either `.` or `,` as
/// the decimal separator (BUG-0043). Returns `null` for anything
/// `double.tryParse` can't make sense of after normalisation.
///
/// Examples:
///   parseDecimal('1.5')   == 1.5
///   parseDecimal('1,5')   == 1.5
///   parseDecimal(' 1,5 ') == 1.5
///   parseDecimal('')      == null
///   parseDecimal(null)    == null
///   parseDecimal('abc')   == null
///
/// Thousands separators aren't a real concern here — nobody types
/// "1,000.0" when entering a single price — so we don't try to
/// distinguish grouping from decimal punctuation.
double? parseDecimal(String? input) {
  if (input == null) return null;
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed.replaceAll(',', '.'));
}

/// FormField validator companion to [parseDecimal] — returns null when
/// the value is empty (callers can decide whether that's allowed by
/// composing with their own required check) or parses cleanly, and a
/// short message otherwise.
String? validateOptionalDecimal(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return parseDecimal(value) == null ? 'Invalid number' : null;
}
