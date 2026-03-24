import '../models/changelog_entry.dart';

List<ChangelogEntry> parseChangelog(String markdown) {
  final entries = <ChangelogEntry>[];
  ChangelogEntry? current;
  String? section;

  for (final line in markdown.split('\n')) {
    // Match versioned entries: ## [0.6.0] - 2026-03-19
    final versionMatch = RegExp(
      r'^## \[(.+?)\](?:\s*-\s*(\S+))?',
    ).firstMatch(line);
    if (versionMatch != null) {
      if (current != null) entries.add(current);
      current = ChangelogEntry(
        version: versionMatch.group(1)!,
        date: versionMatch.group(2),
      );
      section = null;
      continue;
    }

    if (current == null) continue;

    final sectionMatch = RegExp(r'^### (\w+)').firstMatch(line);
    if (sectionMatch != null) {
      section = sectionMatch.group(1)!.toLowerCase();
      continue;
    }

    final itemMatch = RegExp(r'^- (.+)').firstMatch(line);
    if (itemMatch != null && section != null) {
      final text = itemMatch.group(1)!;
      switch (section) {
        case 'added':
          current.added.add(text);
        case 'changed':
          current.changed.add(text);
        case 'fixed':
          current.fixed.add(text);
      }
    }
  }
  if (current != null) entries.add(current);
  return entries;
}
