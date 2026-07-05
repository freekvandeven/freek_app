// Helpers for the nickname / search-alias feature (WISH-0082).
//
// An item can carry a free-text `searchAliases` string; every run of
// whitespace, `,` or `.` starts a new alias word. The words are extra
// search keys: a list search matches when the query appears in the
// title (existing behaviour) OR in any alias word. Aliases are only
// shown on the item's own edit page — never in list tiles.

/// Split a raw nicknames string into individual lowercase alias words.
/// Separators: whitespace, comma, period. Empty segments are dropped.
List<String> parseSearchAliases(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .toLowerCase()
      .split(RegExp(r'[\s,.]+'))
      .where((w) => w.isNotEmpty)
      .toList();
}

/// True when [query] (already lowercased by callers, but lowercased
/// again defensively) matches any alias word parsed from [rawAliases].
/// Uses `contains` semantics to mirror how the existing title searches
/// behave, so partial typing works ("soj" finds alias "soja").
bool matchesSearchAliases(String? rawAliases, String query) {
  final q = query.toLowerCase().trim();
  if (q.isEmpty) return false;
  return parseSearchAliases(rawAliases).any((w) => w.contains(q));
}
