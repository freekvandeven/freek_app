class ChangelogEntry {
  final String version;
  final String date;
  final List<String> added;
  final List<String> changed;
  final List<String> fixed;

  const ChangelogEntry({
    required this.version,
    required this.date,
    this.added = const [],
    this.changed = const [],
    this.fixed = const [],
  });
}
