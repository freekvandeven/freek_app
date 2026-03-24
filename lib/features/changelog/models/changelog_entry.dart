class ChangelogEntry {
  final String version;
  final String? date;
  final List<String> added;
  final List<String> changed;
  final List<String> fixed;

  ChangelogEntry({
    required this.version,
    this.date,
    List<String>? added,
    List<String>? changed,
    List<String>? fixed,
  }) : added = added ?? [],
       changed = changed ?? [],
       fixed = fixed ?? [];

  bool get isUnreleased => version == 'Unreleased';
}
