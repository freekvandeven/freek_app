import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/auth/models/user_profile.dart';
import 'package:personal_app/features/auth/providers/auth_providers.dart';
import 'package:personal_app/features/auth/services/auth_service.dart';
import 'package:personal_app/features/dashboard/dashboard_tiles.dart';
import 'package:personal_app/features/settings/pages/home_screen_order_page.dart';
import 'package:personal_app/presentation/shell/nav_destinations.dart';

class _RecordingAuthService implements AuthService {
  final saved = <List<String>>[];

  @override
  Future<void> updateProfile(UserProfile profile) async {
    saved.add(profile.settings.dashboardOrder);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _user({List<String> dashboardOrder = const []}) => UserProfile(
  id: 'u1',
  email: 'freek@example.com',
  displayName: 'Freek',
  settings: UserSettings(dashboardOrder: dashboardOrder),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

List<String> _keys(List<DashboardTile> tiles) =>
    tiles.map((t) => t.key).toList();

void main() {
  group('kDashboardTiles (WISH-0106)', () {
    test('keys are unique', () {
      final keys = _keys(kDashboardTiles);
      expect(keys.toSet().length, keys.length);
    });

    test('every tile that is a shell branch is marked as one', () {
      // Getting this wrong pushes a tab on top of the shell instead of
      // selecting it — the trap Watchlist fell into when it was promoted
      // to a branch.
      final branchRoutes = {
        for (final destination in kNavDestinations)
          if (destination.key != kMoreDestinationKey) destination.key,
      };

      for (final tile in kDashboardTiles) {
        if (branchRoutes.contains(tile.key)) {
          expect(
            tile.isShellBranch,
            isTrue,
            reason: '${tile.key} is a nav branch but the tile pushes it',
          );
        }
      }
    });

    test('watchlist is treated as a branch', () {
      final watchlist = kDashboardTiles.firstWhere((t) => t.key == 'watchlist');
      expect(watchlist.isShellBranch, isTrue);
    });
  });

  group('resolveDashboardOrder (WISH-0106)', () {
    test('falls back to the declared order', () {
      expect(_keys(resolveDashboardOrder(const [])), _keys(kDashboardTiles));
    });

    test('honours a saved order and appends the rest', () {
      final resolved = _keys(resolveDashboardOrder(['people', 'tasks']));

      expect(resolved.take(2), ['people', 'tasks']);
      expect(resolved.toSet(), _keys(kDashboardTiles).toSet());
    });

    test('drops unknown keys and ignores duplicates', () {
      final resolved = _keys(resolveDashboardOrder(['gone', 'tasks', 'tasks']));

      expect(resolved, isNot(contains('gone')));
      expect(resolved.where((k) => k == 'tasks').length, 1);
      expect(resolved.length, kDashboardTiles.length);
    });
  });

  group('HomeScreenOrderPage (WISH-0106)', () {
    Future<_RecordingAuthService> pump(
      WidgetTester tester, {
      List<String> dashboardOrder = const [],
    }) async {
      final auth = _RecordingAuthService();
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith(
              (ref) => _user(dashboardOrder: dashboardOrder),
            ),
            authServiceProvider.overrideWithValue(auth),
          ],
          child: const MaterialApp(home: HomeScreenOrderPage()),
        ),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('lists every tile with a drag handle', (tester) async {
      await pump(tester);

      expect(
        find.byType(ReorderableDragStartListener),
        findsNWidgets(kDashboardTiles.length),
      );
    });

    testWidgets('dragging saves the new order', (tester) async {
      final auth = await pump(tester);

      final handle = find.byType(ReorderableDragStartListener).at(1);
      final gesture = await tester.startGesture(
        tester.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(auth.saved, hasLength(1));
      final order = auth.saved.single;
      expect(order.first, kDashboardTiles[1].key);
      expect(order[1], kDashboardTiles[0].key);
      expect(order.length, kDashboardTiles.length);
    });

    testWidgets('Reset clears the saved order', (tester) async {
      final auth = await pump(tester, dashboardOrder: ['people']);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(auth.saved.single, isEmpty);
    });
  });
}
