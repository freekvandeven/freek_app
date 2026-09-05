/// Formats a minute count for display: under an hour shows just minutes,
/// whole hours show just hours, and anything else shows both.
///
/// Introduced for task estimates (WISH-0094) and shared with watchlist
/// runtimes (WISH-0098).
///
/// Examples:
///   formatDuration(45)  == '45m'
///   formatDuration(60)  == '1h'
///   formatDuration(90)  == '1h 30m'
String formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours == 0) return '${mins}m';
  if (mins == 0) return '${hours}h';
  return '${hours}h ${mins}m';
}
