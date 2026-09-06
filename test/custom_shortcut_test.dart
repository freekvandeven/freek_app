import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/auth/models/user_profile.dart';
import 'package:personal_app/features/auth/providers/auth_providers.dart';
import 'package:personal_app/features/auth/services/auth_service.dart';
import 'package:personal_app/features/dashboard/custom_shortcut.dart';
import 'package:personal_app/features/dashboard/dashboard_tiles.dart';
import 'package:personal_app/features/settings/pages/home_screen_order_page.dart';

class _RecordingAuthService implements AuthService {
  final saved = <UserSettings>[];

  @override
  Future<void> updateProfile(UserProfile profile) async {
    saved.add(profile.settings);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _user(UserSettings settings) => UserProfile(
  id: 'u1',
  email: 'freek@example.com',
  displayName: 'Freek',
  settings: settings,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  group('CustomShortcut (WISH-0107)', () {
    test('round-trips through a map', () {
      final shortcut = CustomShortcut(
        label: 'Recipe ideas',
        route: '/knowledge/abc123',
        iconKey: 'book',
      );

      final restored = CustomShortcut.fromMap(shortcut.toMap());
      expect(restored.id, shortcut.id);
      expect(restored.label, 'Recipe ideas');
      expect(restored.route, '/knowledge/abc123');
      expect(restored.iconKey, 'book');
    });

    test('falls back to a known icon for an unrecognised key', () {
      // Icons are stored by key precisely so a stale one degrades to a
      // real icon rather than a blank tree-shaken box.
      final restored = CustomShortcut.fromMap({
        'id': 'x',
        'label': 'Thing',
        'route': '/things',
        'iconKey': 'no-such-icon',
      });

      expect(restored.icon, kShortcutIcons[kDefaultShortcutIcon]);
    });

    test('order keys are namespaced away from built-in tiles', () {
      final shortcut = CustomShortcut(label: 'Tasks', route: '/tasks');

      expect(shortcut.orderKey, startsWith('custom:'));
      expect(
        kDashboardTiles.map((t) => t.key),
        isNot(contains(shortcut.orderKey)),
      );
    });

    test('a shortcut renders as a pushed tile, never a branch', () {
      final tile = CustomShortcut(label: 'A', route: '/people').asTile();

      expect(tile.isShellBranch, isFalse);
      expect(tile.route, '/people');
    });

    group('validateShortcutRoute', () {
      test('requires a route that looks like one', () {
        expect(validateShortcutRoute('/people'), isNull);
        expect(validateShortcutRoute('  /people  '), isNull);
        expect(validateShortcutRoute(null), 'A route is required');
        expect(validateShortcutRoute('   '), 'A route is required');
        expect(validateShortcutRoute('people'), 'Routes start with /');
      });
    });
  });

  group('Shortcuts in the home screen order (WISH-0107)', () {
    test('a new shortcut lands at the end rather than vanishing', () {
      final shortcut = CustomShortcut(label: 'Notes', route: '/knowledge');

      final resolved = resolveDashboardOrder(
        // The saved order predates the shortcut.
        kDashboardTiles.map((t) => t.key).toList(),
        shortcuts: [shortcut],
      );

      expect(resolved.last.key, shortcut.orderKey);
      expect(resolved.length, kDashboardTiles.length + 1);
    });

    test('shortcuts take part in the same single order', () {
      final shortcut = CustomShortcut(label: 'Notes', route: '/knowledge');

      final resolved = resolveDashboardOrder(
        [shortcut.orderKey, 'tasks'],
        shortcuts: [shortcut],
      );

      expect(resolved.first.key, shortcut.orderKey);
      expect(resolved[1].key, 'tasks');
    });

    test('a deleted shortcut drops out of a stale order', () {
      final resolved = resolveDashboardOrder([
        'custom:gone',
        'tasks',
      ], shortcuts: const []);

      expect(resolved.map((t) => t.key), isNot(contains('custom:gone')));
      expect(resolved.first.key, 'tasks');
    });
  });

  group('HomeScreenOrderPage shortcuts (WISH-0107)', () {
    Future<_RecordingAuthService> pump(
      WidgetTester tester, {
      List<CustomShortcut> shortcuts = const [],
    }) async {
      final auth = _RecordingAuthService();
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) => _user(
                UserSettings(
                  customShortcuts: shortcuts.map((s) => s.toMap()).toList(),
                ),
              ),
            ),
            authServiceProvider.overrideWithValue(auth),
          ],
          child: const MaterialApp(home: HomeScreenOrderPage()),
        ),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('adding a shortcut saves it', (tester) async {
      final auth = await pump(tester);

      await tester.tap(find.text('Add shortcut'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Label *'),
        'Reading list',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Route *'),
        '/knowledge/abc',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(auth.saved, hasLength(1));
      final saved = auth.saved.single.customShortcuts;
      expect(saved, hasLength(1));
      expect(saved.single['label'], 'Reading list');
      expect(saved.single['route'], '/knowledge/abc');
    });

    testWidgets('a route that is not a route is rejected', (tester) async {
      final auth = await pump(tester);

      await tester.tap(find.text('Add shortcut'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Label *'),
        'Bad',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Route *'),
        'knowledge',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Routes start with /'), findsOneWidget);
      expect(auth.saved, isEmpty);
    });

    testWidgets('an existing shortcut shows its route and can be removed', (
      tester,
    ) async {
      final shortcut = CustomShortcut(
        label: 'Reading list',
        route: '/knowledge/abc',
      );
      final auth = await pump(tester, shortcuts: [shortcut]);

      expect(find.text('Reading list'), findsOneWidget);
      expect(find.text('/knowledge/abc'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(auth.saved.single.customShortcuts, isEmpty);
    });

    testWidgets('built-in tiles have no edit or remove buttons', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });
}
