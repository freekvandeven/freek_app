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

  group('insertTable (WISH-0095)', () {
    test('inserts a 2-column skeleton at an empty caret', () {
      final result = insertTable('', const TextSelection.collapsed(offset: 0));
      expect(
        result.text,
        '| Header 1 | Header 2 |\n| --- | --- |\n| Cell | Cell |',
      );
      expect(result.selection.baseOffset, result.text.length);
    });

    test('adds surrounding newlines when inserted mid-paragraph', () {
      const text = 'before|after';
      final result = insertTable(
        text,
        TextSelection.collapsed(offset: text.indexOf('|')),
      );
      expect(result.text, startsWith('before\n| Header 1'));
      expect(result.text, endsWith('| Cell | Cell |\n|after'));
    });

    test('does not add an extra blank line when already at a clean line '
        'boundary', () {
      const text = 'before\n\nafter';
      final result = insertTable(
        text,
        TextSelection.collapsed(offset: text.indexOf('\n\n') + 1),
      );
      expect(
        result.text,
        'before\n| Header 1 | Header 2 |\n| --- | --- |\n'
        '| Cell | Cell |\nafter',
      );
    });
  });

  group('table row/column edits (WISH-0095)', () {
    const table = '| A | B |\n| --- | --- |\n| 1 | 2 |';

    TextSelection caretIn(String text, String needle) =>
        TextSelection.collapsed(offset: text.indexOf(needle));

    test('addTableRow returns null outside a table', () {
      expect(
        addTableRow('plain text', const TextSelection.collapsed(offset: 2)),
        isNull,
      );
    });

    test('addTableRow appends a row matching the column count and parks '
        'the caret in its first cell', () {
      final result = addTableRow(table, caretIn(table, '1'));
      expect(result, isNotNull);
      expect(result!.text, '$table\n| Cell | Cell |');
      final newRowStart = result.text.indexOf('| Cell | Cell |');
      expect(result.selection.baseOffset, newRowStart + 2);
    });

    test('addTableRow works with the caret on the header row', () {
      final result = addTableRow(table, caretIn(table, 'A'));
      expect(result!.text, '$table\n| Cell | Cell |');
    });

    test('removeTableRow returns null outside a table', () {
      expect(
        removeTableRow('plain text', const TextSelection.collapsed(offset: 2)),
        isNull,
      );
    });

    test('removeTableRow returns null when only header + separator remain', () {
      const headerOnly = '| A | B |\n| --- | --- |';
      expect(removeTableRow(headerOnly, caretIn(headerOnly, 'A')), isNull);
    });

    test('removeTableRow removes the last data row', () {
      const twoRows = '| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |';
      final result = removeTableRow(twoRows, caretIn(twoRows, '3'));
      expect(result!.text, '| A | B |\n| --- | --- |\n| 1 | 2 |');
    });

    test('addTableColumn returns null outside a table', () {
      expect(
        addTableColumn('plain text', const TextSelection.collapsed(offset: 2)),
        isNull,
      );
    });

    test('addTableColumn appends a column to every row', () {
      final result = addTableColumn(table, caretIn(table, '1'));
      expect(
        result!.text,
        '| A | B | Header |\n| --- | --- | --- |\n| 1 | 2 | Cell |',
      );
    });

    test('removeTableColumn returns null outside a table', () {
      expect(
        removeTableColumn(
          'plain text',
          const TextSelection.collapsed(offset: 2),
        ),
        isNull,
      );
    });

    test('removeTableColumn returns null when only one column is left', () {
      const oneColumn = '| A |\n| --- |\n| 1 |';
      expect(removeTableColumn(oneColumn, caretIn(oneColumn, '1')), isNull);
    });

    test('removeTableColumn removes the last column from every row', () {
      final result = removeTableColumn(table, caretIn(table, '1'));
      expect(result!.text, '| A |\n| --- |\n| 1 |');
    });
  });
}
