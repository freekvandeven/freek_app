/// Formats an estimated-duration minute count for display (WISH-0094):
/// under an hour shows just minutes, whole hours show just hours, and
/// anything else shows both.
///
/// Examples:
///   formatTaskDuration(45)  == '45m'
///   formatTaskDuration(60)  == '1h'
///   formatTaskDuration(90)  == '1h 30m'
String formatTaskDuration(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours == 0) return '${mins}m';
  if (mins == 0) return '${hours}h';
  return '${hours}h ${mins}m';
}
