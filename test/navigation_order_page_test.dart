import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/auth/models/user_profile.dart';
import 'package:personal_app/features/auth/providers/auth_providers.dart';
import 'package:personal_app/features/auth/services/auth_service.dart';
import 'package:personal_app/features/settings/pages/navigation_order_page.dart';
import 'package:personal_app/presentation/shell/nav_destinations.dart';

class _RecordingAuthService implements AuthService {
  final saved = <List<String>>[];

  @override
  Future<void> updateProfile(UserProfile profile) async {
    saved.add(profile.settings.navOrder);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProfile _user({List<String> navOrder = const []}) => UserProfile(
  id: 'u1',
  email: 'freek@example.com',
  displayName: 'Freek',
  settings: UserSettings(navOrder: navOrder),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Future<_RecordingAuthService> _pump(
  WidgetTester tester, {
  List<String> navOrder = const [],
  Size size = const Size(1400, 900),
}) async {
  final auth = _RecordingAuthService();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => _user(navOrder: navOrder)),
        authServiceProvider.overrideWithValue(auth),
      ],
      child: const MaterialApp(home: NavigationOrderPage()),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  group('NavigationOrderPage (WISH-0106)', () {
    testWidgets('lists every destination, with More pinned and disabled', (
      tester,
    ) async {
      await _pump(tester);

      for (final destination in kNavDestinations) {
        expect(
          find.text(destination.label),
          findsOneWidget,
          reason: '${destination.key} missing',
        );
      }

      final more = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'More'),
      );
      expect(more.enabled, isFalse);
      // Everything except More can be dragged.
      expect(
        find.byType(ReorderableDragStartListener),
        findsNWidgets(kNavDestinations.length - 1),
      );
    });

    testWidgets('says which destinations reach the bar on this screen', (
      tester,
    ) async {
      // A phone shows four plus More.
      await _pump(tester, size: const Size(400, 900));

      expect(find.text('In the navigation bar'), findsNWidgets(4));
      expect(
        find.text('Under More on this screen'),
        findsNWidgets(kNavDestinations.length - 5),
      );
    });

    testWidgets('dragging a destination saves the new order', (tester) async {
      final auth = await _pump(tester);

      // Drag the second row's handle above the first.
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
      // Tasks was second by default and has moved above Home.
      expect(order.first, 'tasks');
      expect(order[1], 'home');
      // More is always written last.
      expect(order.last, kMoreDestinationKey);
      expect(order.length, kNavDestinations.length);
    });

    testWidgets('Reset is hidden while the order is still the default', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Reset'), findsNothing);
    });

    testWidgets('Reset appears once an order has been chosen', (tester) async {
      await _pump(tester, navOrder: ['watchlist', 'home']);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('Reset clears the saved order back to the default', (
      tester,
    ) async {
      final auth = await _pump(tester, navOrder: ['watchlist', 'home']);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(auth.saved.single, isEmpty);
    });

    testWidgets('a saved order is reflected in the list', (tester) async {
      await _pump(tester, navOrder: ['watchlist']);

      final firstTile = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .first;
      expect((firstTile.title as Text).data, 'Watchlist');
    });
  });
}
