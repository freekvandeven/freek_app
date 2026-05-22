import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/files/models/file_entry.dart';

void main() {
  group('FileEntry', () {
    test('roundtrips through toMap/fromMap', () {
      final entry = FileEntry(
        id: 'abc',
        name: 'report.pdf',
        parentId: 'work',
        isDirectory: false,
        url: 'https://example.com/report.pdf',
        contentType: 'application/pdf',
        sizeBytes: 12345,
        createdAt: DateTime.utc(2026, 5, 22, 10),
        updatedAt: DateTime.utc(2026, 5, 22, 11),
      );
      final copy = FileEntry.fromMap(entry.toMap());
      expect(copy.id, entry.id);
      expect(copy.name, entry.name);
      expect(copy.parentId, entry.parentId);
      expect(copy.isDirectory, entry.isDirectory);
      expect(copy.url, entry.url);
      expect(copy.contentType, entry.contentType);
      expect(copy.sizeBytes, entry.sizeBytes);
      expect(copy.createdAt, entry.createdAt);
      expect(copy.updatedAt, entry.updatedAt);
    });

    test('directory roundtrip leaves url/contentType null', () {
      final dir = FileEntry(name: 'work', isDirectory: true);
      final copy = FileEntry.fromMap(dir.toMap());
      expect(copy.isDirectory, isTrue);
      expect(copy.url, isNull);
      expect(copy.contentType, isNull);
      expect(copy.sizeBytes, 0);
    });

    test('copyWith name updates updatedAt by default', () async {
      final original = FileEntry(name: 'a', isDirectory: false);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final renamed = original.copyWith(name: 'b');
      expect(renamed.name, 'b');
      expect(renamed.id, original.id);
      expect(renamed.updatedAt.isAfter(original.updatedAt), isTrue);
    });

    test('copyWith parentId callback supports clearing', () {
      final entry = FileEntry(name: 'x', parentId: 'p', isDirectory: false);
      final moved = entry.copyWith(parentId: () => null);
      expect(moved.parentId, isNull);
    });
  });
}
