import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/contacts/models/contact.dart';

void main() {
  group('Contact', () {
    test('roundtrips through toMap/fromMap', () {
      final contact = Contact(
        id: 'c1',
        name: 'Mum',
        email: 'mum@example.com',
        phone: '+31612345678',
        dateOfBirth: DateTime.utc(1960, 4, 1),
        notes: 'Calls every Sunday',
        isGroup: false,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 6, 1),
      );
      final copy = Contact.fromMap(contact.toMap());
      expect(copy.id, contact.id);
      expect(copy.name, contact.name);
      expect(copy.email, contact.email);
      expect(copy.phone, contact.phone);
      expect(copy.dateOfBirth, contact.dateOfBirth);
      expect(copy.notes, contact.notes);
      expect(copy.isGroup, contact.isGroup);
      expect(copy.createdAt, contact.createdAt);
      expect(copy.updatedAt, contact.updatedAt);
    });

    test('minimal contact (name only) roundtrips with null optionals', () {
      final c = Contact(name: 'Alex');
      final copy = Contact.fromMap(c.toMap());
      expect(copy.name, 'Alex');
      expect(copy.email, isNull);
      expect(copy.phone, isNull);
      expect(copy.dateOfBirth, isNull);
      expect(copy.notes, '');
      expect(copy.isGroup, isFalse);
    });

    test('isGroup flag flips and persists', () {
      final c = Contact(name: 'Family', isGroup: true);
      final copy = Contact.fromMap(c.toMap());
      expect(copy.isGroup, isTrue);
    });

    test('copyWith email callback clears the value', () {
      final c = Contact(name: 'A', email: 'a@x.com');
      final updated = c.copyWith(email: () => null);
      expect(updated.email, isNull);
    });

    test('copyWith name update preserves other fields', () {
      final c = Contact(name: 'A', email: 'a@x.com', isGroup: true);
      final updated = c.copyWith(name: 'B');
      expect(updated.name, 'B');
      expect(updated.email, 'a@x.com');
      expect(updated.isGroup, isTrue);
    });
  });
}
