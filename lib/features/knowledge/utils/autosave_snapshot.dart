import '../models/knowledge_page.dart';

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
  List<KnowledgeAttachment> attachments = const [],
  String searchAliases = '',
}) {
  return [
    title.trim(),
    content,
    tags.join(','),
    parentId ?? '',
    isWip ? '1' : '0',
    attachments.map((a) => a.url).join(','),
    searchAliases.trim(),
  ].join('||');
}
