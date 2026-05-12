import 'package:flutter/widgets.dart' show TextSelection;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/knowledge/utils/markdown_toolbar_logic.dart';

/// Build a TextSelection that covers [needle] inside [text].
TextSelection _selectionOf(String text, String needle) {
  final idx = text.indexOf(needle);
  expect(idx, isNonNegative, reason: 'needle "$needle" not found in text');
  return TextSelection(baseOffset: idx, extentOffset: idx + needle.length);
}

void main() {
  group('detectMarkdownFormats — line-prefix formats', () {
    test('detects H1 / H2 / H3 from the line containing the caret', () {
      expect(
        detectMarkdownFormats(
          '# Heading',
          const TextSelection.collapsed(offset: 3),
        ),
        contains(MarkdownFormat.h1),
      );
      expect(
        detectMarkdownFormats(
          '## Heading',
          const TextSelection.collapsed(offset: 4),
        ),
        contains(MarkdownFormat.h2),
      );
      expect(
        detectMarkdownFormats(
          '### Heading',
          const TextSelection.collapsed(offset: 5),
        ),
        contains(MarkdownFormat.h3),
      );
    });

    test('only the longest matching heading level wins', () {
      final formats = detectMarkdownFormats(
        '### x',
        const TextSelection.collapsed(offset: 4),
      );
      expect(formats, contains(MarkdownFormat.h3));
      expect(formats, isNot(contains(MarkdownFormat.h2)));
      expect(formats, isNot(contains(MarkdownFormat.h1)));
    });

    test('detects bullet, numbered, and quote line prefixes', () {
      expect(
        detectMarkdownFormats(
          '- item',
          const TextSelection.collapsed(offset: 4),
        ),
        contains(MarkdownFormat.bullet),
      );
      expect(
        detectMarkdownFormats(
          '1. item',
          const TextSelection.collapsed(offset: 4),
        ),
        contains(MarkdownFormat.numbered),
      );
      expect(
        detectMarkdownFormats(
          '> quote',
          const TextSelection.collapsed(offset: 4),
        ),
        contains(MarkdownFormat.quote),
      );
    });

    test('numbered list works for multi-digit counters', () {
      expect(
        detectMarkdownFormats(
          '42. answer',
          const TextSelection.collapsed(offset: 6),
        ),
        contains(MarkdownFormat.numbered),
      );
    });

    test('only inspects the line containing the caret', () {
      const text = '# Heading\n\nNormal paragraph';
      // caret in the paragraph line — no heading
      final formats = detectMarkdownFormats(
        text,
        TextSelection.collapsed(offset: text.indexOf('Normal') + 2),
      );
      expect(formats, isNot(contains(MarkdownFormat.h1)));
    });
  });

  group('detectMarkdownFormats — wrap formats', () {
    test('bold detected when selection is inside the markers', () {
      const text = '**hello**';
      final sel = _selectionOf(text, 'hello');
      expect(detectMarkdownFormats(text, sel), contains(MarkdownFormat.bold));
    });

    test('bold detected when selection encloses the markers', () {
      const text = '**hello**';
      final sel = _selectionOf(text, '**hello**');
      expect(detectMarkdownFormats(text, sel), contains(MarkdownFormat.bold));
    });

    test('bold takes precedence over italic on `**text**`', () {
      const text = '**hello**';
      final sel = _selectionOf(text, 'hello');
      final formats = detectMarkdownFormats(text, sel);
      expect(formats, contains(MarkdownFormat.bold));
      expect(
        formats,
        isNot(contains(MarkdownFormat.italic)),
        reason: '`**` should not double-trigger italic',
      );
    });

    test('italic detected on single-asterisk wrap', () {
      const text = '*hello*';
      final sel = _selectionOf(text, 'hello');
      expect(detectMarkdownFormats(text, sel), contains(MarkdownFormat.italic));
    });

    test('inline code detected on backtick wrap', () {
      const text = '`code`';
      final sel = _selectionOf(text, 'code');
      expect(detectMarkdownFormats(text, sel), contains(MarkdownFormat.code));
    });

    test('wrap formats are NOT detected on a collapsed caret', () {
      const text = '**hello**';
      final formats = detectMarkdownFormats(
        text,
        const TextSelection.collapsed(offset: 4),
      );
      expect(formats, isNot(contains(MarkdownFormat.bold)));
    });

    test('empty text returns empty set', () {
      expect(
        detectMarkdownFormats('', const TextSelection.collapsed(offset: 0)),
        isEmpty,
      );
    });
  });

  group('toggleHeading', () {
    test('adds wrap-style heading when none is present', () {
      const text = 'hello';
      final result = toggleHeading(
        text,
        const TextSelection.collapsed(offset: 0),
        2,
      );
      expect(result.text, '## hello ##');
    });

    test('removes prefix and trailing close when already at that level', () {
      const text = '## hello ##';
      final result = toggleHeading(
        text,
        const TextSelection.collapsed(offset: 5),
        2,
      );
      expect(result.text, 'hello');
    });

    test('removes leading prefix when there is no trailing close', () {
      const text = '## hello';
      final result = toggleHeading(
        text,
        const TextSelection.collapsed(offset: 5),
        2,
      );
      expect(result.text, 'hello');
    });

    test('switches between heading levels (H1 → H3)', () {
      const text = '# hello #';
      final result = toggleHeading(
        text,
        const TextSelection.collapsed(offset: 4),
        3,
      );
      expect(result.text, '### hello ###');
    });

    test('only modifies the line containing the caret', () {
      const text = '# top\nbody\n# bottom';
      final result = toggleHeading(
        text,
        TextSelection.collapsed(offset: text.indexOf('body')),
        2,
      );
      expect(result.text, '# top\n## body ##\n# bottom');
    });
  });

  group('wrapSelection / unwrapSelection', () {
    test('wrap on a collapsed caret parks the caret between markers', () {
      const text = 'hello';
      final result = wrapSelection(
        text,
        const TextSelection.collapsed(offset: 2),
        '**',
        '**',
      );
      expect(result.text, 'he****llo');
      // Caret should sit right after the opening `**`
      expect(result.selection.baseOffset, text.indexOf('he') + 2 + 2);
    });

    test('wrap on a real selection brackets the selected text', () {
      const text = 'hello world';
      final sel = _selectionOf(text, 'world');
      final result = wrapSelection(text, sel, '**', '**');
      expect(result.text, 'hello **world**');
    });

    test('unwrap removes inside-marker pair', () {
      const text = '**hello**';
      final sel = _selectionOf(text, 'hello');
      final result = unwrapSelection(text, sel, '**');
      expect(result.text, 'hello');
    });

    test('unwrap removes whole-marker selection too', () {
      const text = 'pre **hello** post';
      final sel = _selectionOf(text, '**hello**');
      final result = unwrapSelection(text, sel, '**');
      expect(result.text, 'pre hello post');
    });

    test('unwrap is a no-op when no markers are present', () {
      const text = 'hello world';
      final sel = _selectionOf(text, 'hello');
      final result = unwrapSelection(text, sel, '**');
      expect(result.text, text);
    });
  });

  group('insertAtLineStart / removeLinePrefix / removeNumberedPrefix', () {
    test('insertAtLineStart adds the prefix to the right line', () {
      const text = 'first\nsecond';
      final result = insertAtLineStart(
        text,
        TextSelection.collapsed(offset: text.indexOf('second') + 2),
        '- ',
      );
      expect(result.text, 'first\n- second');
    });

    test('removeLinePrefix strips the prefix when present', () {
      const text = '- item';
      final result = removeLinePrefix(
        text,
        const TextSelection.collapsed(offset: 4),
        '- ',
      );
      expect(result.text, 'item');
    });

    test('removeLinePrefix is a no-op when prefix absent', () {
      const text = 'plain';
      final result = removeLinePrefix(
        text,
        const TextSelection.collapsed(offset: 3),
        '- ',
      );
      expect(result.text, 'plain');
    });

    test('removeNumberedPrefix strips multi-digit list markers', () {
      const text = '42. answer';
      final result = removeNumberedPrefix(
        text,
        const TextSelection.collapsed(offset: 6),
      );
      expect(result.text, 'answer');
    });

    test('removeNumberedPrefix is a no-op when line is not numbered', () {
      const text = '- bullet';
      final result = removeNumberedPrefix(
        text,
        const TextSelection.collapsed(offset: 4),
      );
      expect(result.text, '- bullet');
    });
  });
}
