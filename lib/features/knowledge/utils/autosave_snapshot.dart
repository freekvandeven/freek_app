/// Canonical string fingerprint of the autosaved fields of a knowledge
/// page. Compared against the previous snapshot to decide whether the
/// autosave timer should actually save (BUG-0033 — browser-throttled
/// Timer.periodic was firing redundant saves after tab refocus).
///
/// Any change in any field flips the snapshot string, so the comparison
/// is just `previous == current`.
String knowledgeAutosaveSnapshot({
  required String title,
  required String content,
  required List<String> tags,
  required String? parentId,
  required bool isWip,
}) {
  return [
    title.trim(),
    content,
    tags.join(','),
    parentId ?? '',
    isWip ? '1' : '0',
  ].join('||');
}
