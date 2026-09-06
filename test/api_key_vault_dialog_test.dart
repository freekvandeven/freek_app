import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/passwords/models/password_entry.dart';
import 'package:personal_app/features/passwords/providers/vault_providers.dart';
import 'package:personal_app/presentation/widgets/api_key_vault_dialog.dart';

class _FakeVaultEntriesNotifier extends VaultEntriesNotifier {
  final List<DecryptedPasswordEntry> entries;
  final added = <({String title, String password, String? category})>[];
  _FakeVaultEntriesNotifier(this.entries);

  @override
  Stream<List<DecryptedPasswordEntry>> build() => Stream.value(entries);

  @override
  Future<void> addEntry({
    required String title,
    String? username,
    required String password,
    String? url,
    String? notes,
    String? category,
  }) async {
    added.add((title: title, password: password, category: category));
  }
}

DecryptedPasswordEntry _entry(String title, String password) =>
    DecryptedPasswordEntry(
      entry: PasswordEntry(title: title, encryptedPassword: 'x'),
      password: password,
    );

const _spec = ApiKeyVaultSpec(
  serviceName: 'TMDB',
  dialogTitle: 'TMDB API key',
  fieldLabel: 'API key (v3 auth)',
  vaultEntryTitle: 'TMDB API Key',
  vaultMatch: 'tmdb',
  vaultEntryUrl: 'https://www.themoviedb.org/settings/api',
);

/// Opens the dialog with the vault either locked or unlocked, collecting
/// whatever key the flow ends up saving.
Future<({List<String> saved, _FakeVaultEntriesNotifier vault})> _open(
  WidgetTester tester, {
  required bool locked,
  List<DecryptedPasswordEntry> entries = const [],
}) async {
  final saved = <String>[];
  final vault = _FakeVaultEntriesNotifier(entries);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // The vault key is what locked/unlocked derives from.
        vaultKeyProvider.overrideWith(
          (ref) => locked ? null : Uint8List.fromList(List.filled(32, 1)),
        ),
        vaultEntriesProvider.overrideWith(() => vault),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showApiKeyVaultDialog(
                  context: context,
                  ref: ref,
                  spec: _spec,
                  onSaved: (key) async => saved.add(key),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return (saved: saved, vault: vault);
}

void main() {
  group('matchingVaultEntries (WISH-0102)', () {
    test(
      'finds entries whose title contains the match, case-insensitively',
      () {
        final entries = [
          _entry('TMDB API Key', 'tmdb-key'),
          _entry('Gemini API Key', 'gemini-key'),
          _entry('my tmdb backup', 'other-key'),
        ];

        final found = matchingVaultEntries(entries, 'tmdb');

        expect(found.map((e) => e.password), ['tmdb-key', 'other-key']);
      },
    );

    test('returns nothing when no entry matches', () {
      expect(
        matchingVaultEntries([_entry('Gemini API Key', 'k')], 'tmdb'),
        isEmpty,
      );
    });

    test('the title the dialog saves is found by its own match term', () {
      final saved = _entry(_spec.vaultEntryTitle, 'k');
      expect(matchingVaultEntries([saved], _spec.vaultMatch), hasLength(1));
    });
  });

  group('showApiKeyVaultDialog (WISH-0102)', () {
    testWidgets('offers the vault when it is unlocked', (tester) async {
      await _open(tester, locked: false);

      expect(find.text('TMDB API key'), findsOneWidget);
      expect(find.text('Load from Password Vault'), findsOneWidget);
    });

    testWidgets('explains itself instead when the vault is locked', (
      tester,
    ) async {
      await _open(tester, locked: true);

      expect(find.text('Load from Password Vault'), findsNothing);
      expect(find.textContaining('Unlock your Password Vault'), findsOneWidget);
    });

    testWidgets('saving a typed key hands it to the caller', (tester) async {
      final result = await _open(tester, locked: false);

      await tester.enterText(find.byType(TextField), 'typed-key');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(result.saved, ['typed-key']);
    });

    testWidgets('an empty key is not saved', (tester) async {
      final result = await _open(tester, locked: false);

      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(result.saved, isEmpty);
      // The dialog stays open so the user can correct it.
      expect(find.text('TMDB API key'), findsOneWidget);
    });

    testWidgets('offers to put a typed key into the vault', (tester) async {
      final result = await _open(tester, locked: false);

      await tester.enterText(find.byType(TextField), 'typed-key');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Save to Password Vault?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Save to Vault'));
      await tester.pumpAndSettle();

      expect(result.vault.added, hasLength(1));
      expect(result.vault.added.single.title, 'TMDB API Key');
      expect(result.vault.added.single.password, 'typed-key');
      expect(result.vault.added.single.category, 'API Keys');
    });

    testWidgets('does not offer the vault when it is locked', (tester) async {
      final result = await _open(tester, locked: true);

      await tester.enterText(find.byType(TextField), 'typed-key');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(result.saved, ['typed-key']);
      expect(find.text('Save to Password Vault?'), findsNothing);
    });

    testWidgets('loading a single matching entry applies it straight away', (
      tester,
    ) async {
      final result = await _open(
        tester,
        locked: false,
        entries: [
          _entry('TMDB API Key', 'from-vault'),
          _entry('Gemini API Key', 'wrong-key'),
        ],
      );

      await tester.tap(find.text('Load from Password Vault'));
      await tester.pumpAndSettle();

      expect(result.saved, ['from-vault']);
      expect(find.text('TMDB API key loaded from vault'), findsOneWidget);
    });

    testWidgets('asks which entry to use when several match', (tester) async {
      final result = await _open(
        tester,
        locked: false,
        entries: [
          _entry('TMDB API Key', 'first'),
          _entry('TMDB API Key (old)', 'second'),
        ],
      );

      await tester.tap(find.text('Load from Password Vault'));
      await tester.pumpAndSettle();

      expect(find.text('Select Vault Entry'), findsOneWidget);
      await tester.tap(find.text('TMDB API Key (old)'));
      await tester.pumpAndSettle();

      expect(result.saved, ['second']);
    });

    testWidgets('says so when the vault holds no matching entry', (
      tester,
    ) async {
      final result = await _open(
        tester,
        locked: false,
        entries: [_entry('Gemini API Key', 'gemini')],
      );

      await tester.tap(find.text('Load from Password Vault'));
      await tester.pumpAndSettle();

      expect(result.saved, isEmpty);
      expect(
        find.textContaining('No TMDB API key found in vault'),
        findsOneWidget,
      );
    });
  });
}
