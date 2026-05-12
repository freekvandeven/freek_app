import 'package:flutter/widgets.dart' show TextSelection;

/// Markdown formats the editor toolbar recognises. Used for both
/// active-state detection (which buttons should light up) and toggle
/// actions (what to do when a button is clicked).
enum MarkdownFormat { h1, h2, h3, bold, italic, code, bullet, numbered, quote }

/// Result of a toolbar toggle — the new full text and the selection /
/// caret to apply afterwards.
class ToolbarEditResult {
  final String text;
  final TextSelection selection;
  const ToolbarEditResult(this.text, this.selection);
}

final _numberedRe = RegExp(r'^\d+\.\s');
final _trailingHashesRe = RegExp(r'\s+#+\s*$');
final _leadingHeadingRe = RegExp(r'^#{1,6}\s+');

/// Inspects [text] at [sel] and returns the set of markdown formats
/// currently in effect.
///
/// - Line-prefix formats (headings, lists, blockquote) work with a
///   collapsed cursor — they check the line the caret is on.
/// - Wrap formats (bold, italic, inline code) require a non-empty
///   selection that either sits between matching markers or fully
///   encloses them. Bold is checked before italic so `**text**`
///   doesn't false-positive italic.
Set<MarkdownFormat> detectMarkdownFormats(String text, TextSelection sel) {
  if (text.isEmpty) return const {};
  final start = sel.start.clamp(0, text.length);
  // lastIndexOf throws on a -1 start, which would happen when the caret
  // is at the very beginning of the text. Special-case that path so a
  // selection at offset 0 doesn't crash.
  final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final lineEndIdx = text.indexOf('\n', start);
  final lineEnd = lineEndIdx == -1 ? text.length : lineEndIdx;
  final line = text.substring(lineStart, lineEnd);

  final out = <MarkdownFormat>{};
  if (line.startsWith('### ')) {
    out.add(MarkdownFormat.h3);
  } else if (line.startsWith('## ')) {
    out.add(MarkdownFormat.h2);
  } else if (line.startsWith('# ')) {
    out.add(MarkdownFormat.h1);
  }
  if (line.startsWith('- ')) out.add(MarkdownFormat.bullet);
  if (_numberedRe.hasMatch(line)) out.add(MarkdownFormat.numbered);
  if (line.startsWith('> ')) out.add(MarkdownFormat.quote);

  if (!sel.isCollapsed) {
    bool wrapped(String marker) {
      final m = marker.length;
      if (sel.start >= m &&
          sel.end + m <= text.length &&
          text.substring(sel.start - m, sel.start) == marker &&
          text.substring(sel.end, sel.end + m) == marker) {
        return true;
      }
      if (sel.end - sel.start >= 2 * m) {
        final selText = text.substring(sel.start, sel.end);
        if (selText.startsWith(marker) && selText.endsWith(marker)) {
          return true;
        }
      }
      return false;
    }

    final bold = wrapped('**');
    if (bold) out.add(MarkdownFormat.bold);
    if (!bold && wrapped('*')) out.add(MarkdownFormat.italic);
    if (wrapped('`')) out.add(MarkdownFormat.code);
  }
  return out;
}

/// Toggle the heading prefix on the line containing [sel] to [level]
/// (1, 2, or 3). If the line already has that level, the heading is
/// removed; otherwise any existing heading prefix is replaced and the
/// new wrap-style heading is applied (`## text ##`).
ToolbarEditResult toggleHeading(String text, TextSelection sel, int level) {
  final start = sel.start.clamp(0, text.length);
  // lastIndexOf throws on a -1 start, which would happen when the caret
  // is at the very beginning of the text. Special-case that path so a
  // selection at offset 0 doesn't crash.
  final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final lineEndIdx = text.indexOf('\n', start);
  final lineEnd = lineEndIdx == -1 ? text.length : lineEndIdx;
  final line = text.substring(lineStart, lineEnd);
  final hashes = '#' * level;
  final activePrefix = '$hashes ';

  String newLine;
  if (line.startsWith(activePrefix)) {
    newLine = line
        .substring(activePrefix.length)
        .replaceFirst(_trailingHashesRe, '');
  } else {
    final stripped = line
        .replaceFirst(_leadingHeadingRe, '')
        .replaceFirst(_trailingHashesRe, '');
    newLine = '$activePrefix$stripped $hashes';
  }
  final newText =
      text.substring(0, lineStart) + newLine + text.substring(lineEnd);
  final caret = (lineStart + newLine.length).clamp(0, newText.length);
  return ToolbarEditResult(newText, TextSelection.collapsed(offset: caret));
}

/// Wrap the current selection in [marker] (e.g. `**`). On a collapsed
/// caret, inserts both opening and closing markers and parks the caret
/// between them so typing inserts content immediately.
ToolbarEditResult wrapSelection(
  String text,
  TextSelection sel,
  String before,
  String after,
) {
  if (sel.isCollapsed) {
    final pos = sel.start.clamp(0, text.length);
    final newText =
        text.substring(0, pos) + before + after + text.substring(pos);
    return ToolbarEditResult(
      newText,
      TextSelection.collapsed(offset: pos + before.length),
    );
  }
  final selected = text.substring(sel.start, sel.end);
  final replacement = before + selected + after;
  final newText =
      text.substring(0, sel.start) + replacement + text.substring(sel.end);
  return ToolbarEditResult(
    newText,
    TextSelection.collapsed(offset: sel.start + replacement.length),
  );
}

/// Inverse of [wrapSelection] for symmetric markers. Handles both
/// "selection sits inside markers" and "selection fully encloses
/// markers". Returns the input unchanged if no markers are found.
ToolbarEditResult unwrapSelection(
  String text,
  TextSelection sel,
  String marker,
) {
  if (sel.isCollapsed) return ToolbarEditResult(text, sel);
  final m = marker.length;
  final selText = text.substring(sel.start, sel.end);

  if (selText.length >= 2 * m &&
      selText.startsWith(marker) &&
      selText.endsWith(marker)) {
    final inner = selText.substring(m, selText.length - m);
    final newText =
        text.substring(0, sel.start) + inner + text.substring(sel.end);
    return ToolbarEditResult(
      newText,
      TextSelection(
        baseOffset: sel.start,
        extentOffset: sel.start + inner.length,
      ),
    );
  }
  if (sel.start >= m &&
      sel.end + m <= text.length &&
      text.substring(sel.start - m, sel.start) == marker &&
      text.substring(sel.end, sel.end + m) == marker) {
    final newText =
        text.substring(0, sel.start - m) +
        selText +
        text.substring(sel.end + m);
    return ToolbarEditResult(
      newText,
      TextSelection(baseOffset: sel.start - m, extentOffset: sel.end - m),
    );
  }
  return ToolbarEditResult(text, sel);
}

/// Prepend [prefix] to the line at [sel]'s start.
ToolbarEditResult insertAtLineStart(
  String text,
  TextSelection sel,
  String prefix,
) {
  final start = sel.start.clamp(0, text.length);
  // lastIndexOf throws on a -1 start, which would happen when the caret
  // is at the very beginning of the text. Special-case that path so a
  // selection at offset 0 doesn't crash.
  final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final newText =
      text.substring(0, lineStart) + prefix + text.substring(lineStart);
  return ToolbarEditResult(
    newText,
    TextSelection.collapsed(offset: start + prefix.length),
  );
}

/// Remove [prefix] from the start of the line at [sel] when present.
/// No-op when the line doesn't start with the prefix.
ToolbarEditResult removeLinePrefix(
  String text,
  TextSelection sel,
  String prefix,
) {
  final start = sel.start.clamp(0, text.length);
  // lastIndexOf throws on a -1 start, which would happen when the caret
  // is at the very beginning of the text. Special-case that path so a
  // selection at offset 0 doesn't crash.
  final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final lineEndIdx = text.indexOf('\n', start);
  final lineEnd = lineEndIdx == -1 ? text.length : lineEndIdx;
  final line = text.substring(lineStart, lineEnd);
  if (!line.startsWith(prefix)) return ToolbarEditResult(text, sel);
  final newText =
      text.substring(0, lineStart) +
      line.substring(prefix.length) +
      text.substring(lineEnd);
  final caret = (start - prefix.length).clamp(lineStart, newText.length);
  return ToolbarEditResult(newText, TextSelection.collapsed(offset: caret));
}

/// Remove the numbered-list marker (`\d+\.\s`) from the start of the
/// line at [sel] when present. No-op when the line isn't a numbered
/// list entry.
ToolbarEditResult removeNumberedPrefix(String text, TextSelection sel) {
  final start = sel.start.clamp(0, text.length);
  // lastIndexOf throws on a -1 start, which would happen when the caret
  // is at the very beginning of the text. Special-case that path so a
  // selection at offset 0 doesn't crash.
  final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final lineEndIdx = text.indexOf('\n', start);
  final lineEnd = lineEndIdx == -1 ? text.length : lineEndIdx;
  final line = text.substring(lineStart, lineEnd);
  final match = _numberedRe.firstMatch(line);
  if (match == null) return ToolbarEditResult(text, sel);
  final removed = match.end;
  final newText =
      text.substring(0, lineStart) +
      line.substring(removed) +
      text.substring(lineEnd);
  final caret = (start - removed).clamp(lineStart, newText.length);
  return ToolbarEditResult(newText, TextSelection.collapsed(offset: caret));
}
