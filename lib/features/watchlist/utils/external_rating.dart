import '../../../utils/decimal_input.dart';

/// Validates a hand-typed public rating (WISH-0101): optional, a valid
/// decimal, and within the 0-10 scale the badge renders. Without the range
/// check a slip like "78" would render as 78/10.
String? validateExternalRating(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parsed = parseDecimal(value);
  if (parsed == null) return 'Invalid number';
  if (parsed < 0 || parsed > 10) return 'Must be between 0 and 10';
  return null;
}
